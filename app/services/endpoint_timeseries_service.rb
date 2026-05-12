# app/services/endpoint_timeseries_service.rb
class EndpointTimeseriesService
  include ClickhouseClient
  include StatusClassifier
  include ClickhouseTableSelector
  include TimeAgoCalculator
  include UtcTimeParser
  include SqlFilterBuilder
  DEFAULT_BUCKET_MINUTES = 15

  def initialize(org_id:, endpoint_id:, bucket_minutes: nil,
                 start_time: nil, end_time: nil,
                 host: nil, device_id: nil, isp: nil, region: nil,
                 location_id: nil, router_id: nil, sites_type: nil, **_unused)
    @org_id         = org_id
    @endpoint_id    = endpoint_id
    @bucket_minutes = (bucket_minutes.presence || DEFAULT_BUCKET_MINUTES).to_i

    # Explicit start_time/end_time required for 24-hour window boundaries.
    @start_time = parse_time_utc(start_time, 24.hours.ago.utc)
    @end_time   = parse_time_utc(end_time, Time.current.utc)

    # Optional extra filters (applied to device detail query only)
    @host       = host
    @device_id  = device_id
    @isp        = isp
    @region     = region
    @location_id = location_id
    @router_id  = router_id
  end

  def call
    raise ArgumentError, "endpoint_id is required" if @endpoint_id.blank?

    table_type       = select_table(@start_time, @end_time)
    bucket_data      = fetch_timeseries_buckets(table_type)
    device_data      = fetch_device_details(table_type)
    endpoint_config  = load_endpoint_config

    timeseries       = build_timeseries(bucket_data, endpoint_config)
    response_eff     = build_response_efficiency(timeseries)
    devices_details  = build_devices_details(device_data, endpoint_config)

    {
      time_window: {
        start_time: @start_time.iso8601,
        end_time:   @end_time.iso8601,
        bucket_minutes: @bucket_minutes
      },
      response_efficiency: response_eff,
      endpoint:       build_endpoint_info(endpoint_config),
      timeseries:     timeseries,
      devices_details: devices_details
    }
  end

  private

  def fetch_timeseries_buckets(table_type)
    bucket_seconds = @bucket_minutes * 60

    if table_type == :rollup
      query = <<~SQL
        SELECT
          toStartOfInterval(ts, INTERVAL #{bucket_seconds} second) AS time_bucket,
          round(sum(sum_latency) / nullIf(sum(samples), 0), 2) AS avg_latency_ms,
          sum(good_count) AS good_count,
          sum(warning_count) AS warning_count,
          sum(critical_count) AS critical_count,
          sum(down_count) AS down_count,
          sum(samples) AS sample_count
        FROM router_metrics_rollup
        WHERE org_id = '#{@org_id}'
          AND endpoint_id = '#{sanitize(@endpoint_id)}'
          AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.utc}') AND parseDateTimeBestEffort('#{@end_time.utc}')
          AND samples > 0
        GROUP BY time_bucket
        ORDER BY time_bucket ASC
      SQL
    else
      query = <<~SQL
        SELECT
          toStartOfInterval(ts, INTERVAL #{bucket_seconds} second) AS time_bucket,
          round(avg(latency_ms), 2) AS avg_latency_ms,
          countIf(status = 1) AS good_count,
          countIf(status = 2) AS warning_count,
          countIf(status = 3) AS critical_count,
          countIf(status = 4) AS down_count,
          count() AS sample_count
        FROM router_metrics_raw
        WHERE org_id = '#{@org_id}'
          AND endpoint_id = '#{sanitize(@endpoint_id)}'
          AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.utc}') AND parseDateTimeBestEffort('#{@end_time.utc}')
        GROUP BY time_bucket
        ORDER BY time_bucket ASC
      SQL
    end

    client.select_all(query).to_a
  end

  def fetch_device_details(table_type)
    if table_type == :rollup
      query = <<~SQL
        SELECT
          device_id,
          router_inventory_id,
          any(region) AS region,
          max(ts) AS last_seen,
          round(sum(sum_latency) / nullIf(sum(samples), 0), 2) AS avg_latency_ms,
          sum(good_count) AS good_count,
          sum(warning_count) AS warning_count,
          sum(critical_count) AS critical_count,
          sum(down_count) AS down_count,
          sum(samples) AS sample_count
        FROM router_metrics_rollup
        WHERE org_id = '#{@org_id}'
          AND endpoint_id = '#{sanitize(@endpoint_id)}'
          AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.utc}') AND parseDateTimeBestEffort('#{@end_time.utc}')
          AND samples > 0
          #{extra_device_filters}
        GROUP BY device_id, router_inventory_id
        ORDER BY last_seen DESC
      SQL
    else
      query = <<~SQL
        SELECT
          device_id,
          router_inventory_id,
          any(region) AS region,
          max(ts) AS last_seen,
          round(avg(latency_ms), 2) AS avg_latency_ms,
          countIf(status = 1) AS good_count,
          countIf(status = 2) AS warning_count,
          countIf(status = 3) AS critical_count,
          countIf(status = 4) AS down_count,
          count() AS sample_count
        FROM router_metrics_raw
        WHERE org_id = '#{@org_id}'
          AND endpoint_id = '#{sanitize(@endpoint_id)}'
          AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.utc}') AND parseDateTimeBestEffort('#{@end_time.utc}')
          #{extra_device_filters}
        GROUP BY device_id, router_inventory_id
        ORDER BY last_seen DESC
      SQL
    end

    client.select_all(query).to_a
  end

  def build_timeseries(bucket_data, endpoint_config)
    data_by_bucket = bucket_data.index_by do |row|
      truncate_to_bucket(parse_time_utc(row["time_bucket"]))
    end

    all_buckets = generate_bucket_timestamps

    all_buckets.map do |bucket_ts|
      row = data_by_bucket[bucket_ts]

      if row
        latency      = row["avg_latency_ms"].to_f
        status       = determine_status_from_counts(
          row["good_count"].to_i,
          row["warning_count"].to_i,
          row["critical_count"].to_i,
          row["down_count"].to_i
        )

        {
          timestamp:     bucket_ts.iso8601,
          time_ago:      calculate_time_ago(bucket_ts),
          response_time: latency.round(2),
          status:        status
        }
      else
        {
          timestamp:     bucket_ts.iso8601,
          time_ago:      calculate_time_ago(bucket_ts),
          response_time: nil,
          status:        "no_data"
        }
      end
    end
  end

  def build_response_efficiency(timeseries)
    statuses = timeseries.map { |p| p[:status] }
    data_points = statuses.reject { |s| s == "no_data" }

    {
      good:        data_points.count { |s| s == "good" },
      warning:     data_points.count { |s| s == "warning" },
      critical:    data_points.count { |s| s == "critical" },
      down:        data_points.count { |s| s == "down" },
      total_count: data_points.size
    }
  end

  def build_devices_details(device_data, endpoint_config)
    device_data.map do |row|
      timestamp = parse_time_utc(row["last_seen"])
      status    = determine_status_from_counts(
        row["good_count"].to_i,
        row["warning_count"].to_i,
        row["critical_count"].to_i,
        row["down_count"].to_i
      )

      {
        router_inventory_id: row["router_inventory_id"],
        mac_address:   row["device_id"],
        timestamp:     timestamp&.iso8601,
        time_ago:      calculate_time_ago(timestamp),
        response_time: row["avg_latency_ms"].to_f.round(2),
        status:        status
      }
    end
  end

  def build_endpoint_info(endpoint_config)
    return { endpoint_id: @endpoint_id, host: nil, group_name: nil, type: nil } unless endpoint_config

    {
      endpoint_id: endpoint_config.id.to_s,
      host:        endpoint_config.host,
      group_name:  endpoint_config.endpoint_monitoring_group&.name,
      type:        endpoint_config.monitoring_mode
    }
  end

  def load_endpoint_config
    EndpointMonitoringEndpoint
      .includes(:endpoint_monitoring_group)
      .find_by(id: @endpoint_id)
  end

  def generate_bucket_timestamps
    timestamps = []
    current    = truncate_to_bucket(@start_time)

    while current <= @end_time
      timestamps << current
      current = current + @bucket_minutes.minutes
    end

    timestamps
  end

  def truncate_to_bucket(time)
    return @start_time unless time
    bucket_seconds = @bucket_minutes * 60
    epoch = time.to_i
    Time.at((epoch / bucket_seconds) * bucket_seconds).utc
  end

  def extra_device_filters
    filters = build_sql_filters(:device_id, :isp, :region, :location_id, :router_id)
    filters.any? ? "AND #{filters.join(' AND ')}" : ""
  end

  def sanitize(value)
    value.to_s.gsub("'", "''")
  end
end
