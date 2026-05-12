class UplinkTimeseriesService
  include ClickhouseClient
  include TimeAgoCalculator
  include UtcTimeParser

  # Table selection based on time range for optimal query performance
  RAW_TABLE = "internet_quality_raw".freeze
  TABLE_5M = "internet_quality_5m".freeze
  TABLE_1H = "internet_quality_1h".freeze
  TABLE_1D = "internet_quality_1d".freeze

  def initialize(org_id:, device_id:, start_time:, end_time:,
                 uplink_id: nil, uplink_type: nil, bucket_minutes: nil,
                 host: nil, endpoint_id: nil, isp: nil, region: nil,
                 location_id: nil, router_id: nil, sites_type: nil)
    @org_id = org_id
    @device_id = device_id
    @uplink_id = uplink_id
    @uplink_type = uplink_type
    @start_time = start_time
    @end_time = end_time
    @bucket_minutes = bucket_minutes&.to_i || 1
    # Accept but ignore other dashboard filter parameters for consistency
    # This service is device-specific and doesn't use these filters
  end

  def call
    results = client.select_all(build_timeseries_query).to_a
    {
      time_window: build_time_window(@start_time, @end_time, bucket_minutes: @bucket_minutes),
      latency: build_metric_series(results, :latency),
      loss: build_metric_series(results, :loss)
    }
  end

  private

  def select_table
    last_minutes = ((@end_time - @start_time) / 60).to_i

    if last_minutes <= 2880 # 2 days
      RAW_TABLE
    elsif last_minutes <= 43200 # 30 days
      TABLE_5M
    elsif last_minutes <= 525600 # 1 year
      TABLE_1H
    else
      TABLE_1D
    end
  end

  def use_aggregated_table?
    select_table != RAW_TABLE
  end

  def build_timeseries_query
    table = select_table
    bucket_interval = "#{@bucket_minutes} MINUTE"

    if use_aggregated_table?
      # For aggregated tables, calculate averages from sums
      <<~SQL
        SELECT
          toStartOfInterval(ts, INTERVAL #{bucket_interval}) AS bucket_time,
          uplink_id,
          uplink_type,
          avg(sum_latency / samples) AS avg_latency_ms,
          avg(sum_loss / samples) AS avg_loss_pct,
          sum(samples) AS sample_count
        FROM #{table}
        WHERE #{build_where_conditions}
          AND ts >= '#{@start_time.strftime('%Y-%m-%d %H:%M:%S')}'
          AND ts <= '#{@end_time.strftime('%Y-%m-%d %H:%M:%S')}'
        GROUP BY bucket_time, uplink_id, uplink_type
        ORDER BY bucket_time, uplink_id
      SQL
    else
      # For raw table, use direct averages
      <<~SQL
        SELECT
          ts AS bucket_time,
          uplink_id,
          uplink_type,
          avg(latency_ms) AS avg_latency_ms,
          avg(loss_pct) AS avg_loss_pct,
          count() AS sample_count
        FROM #{table}
        WHERE #{build_where_conditions}
          AND ts >= '#{@start_time.strftime('%Y-%m-%d %H:%M:%S')}'
          AND ts <= '#{@end_time.strftime('%Y-%m-%d %H:%M:%S')}'
        GROUP BY bucket_time, uplink_id, uplink_type
        ORDER BY bucket_time, uplink_id
      SQL
    end
  end

  def build_metric_series(results, metric_type)
    uplinks_data = {}

    results.each do |row|
      uplink_id = row["uplink_id"] || "unknown"
      uplinks_data[uplink_id] ||= []

      base = {
        timestamp: row["bucket_time"],
        epoch_ts: row["bucket_time"].is_a?(String) ? normalize_to_utc(row["bucket_time"])&.to_i : row["bucket_time"]&.to_i,
        time_ago: calculate_time_ago(row["bucket_time"]),
        sample_count: row["sample_count"] || 0
      }

      metric_data =
        case metric_type
        when :latency
          base.merge(avg_latency_ms: row["avg_latency_ms"]&.round(2) || 0)
        when :loss
          base.merge(avg_loss_pct: row["avg_loss_pct"]&.round(2) || 0)
        end

      uplinks_data[uplink_id] << metric_data
    end

    uplinks_data.map do |uplink_id, timeseries|
      {
        uplink_id: uplink_id,
        uplink_type: get_uplink_type_from_results(results, uplink_id),
        timeseries: timeseries.sort_by { |t| t[:timestamp] }
      }
    end
  end

  def build_where_conditions
    conditions = [
      "org_id = '#{@org_id}'",
      "device_id = '#{@device_id}'"
    ]

    conditions << "uplink_id = '#{@uplink_id}'" if @uplink_id.present?
    conditions << "uplink_type = '#{@uplink_type}'" if @uplink_type.present?

    conditions.join(" AND ")
  end

  def get_uplink_type_from_results(results, uplink_id)
    result = results.find { |r| r["uplink_id"] == uplink_id }
    result&.dig("uplink_type") || "unknown"
  end
end
