# app/services/grouped_timeseries_service.rb
# Simple filtered timeseries dashboard API
# Provides time-bucketed performance data based on applied filters
# Supports comprehensive filtering and performance classification
class GroupedTimeseriesService
  include StatusClassifier
  include ClickhouseClient
  include ClickhouseTableSelector
  include TimeAgoCalculator
  include SqlFilterBuilder
  include UtcTimeParser

  def initialize(org_id:, start_time:, end_time:, bucket_minutes: nil,
                 host: nil, endpoint_id: nil, device_id: nil, isp: nil, region: nil,
                 location_id: nil, router_id: nil, sites_type: nil)
    @org_id = org_id
    @start_time = start_time
    @end_time = end_time
    @bucket_minutes = bucket_minutes.presence&.to_i

    # Optional filters
    @host = host
    @endpoint_id = endpoint_id
    @device_id = device_id
    @isp = isp
    @region = region
    @location_id = location_id
    @router_id = router_id
    @sites_type = sites_type

    # Cache frequently used objects
    @table_type = nil
    @table_cols = nil
  end

  def call
    @table_type = select_table(@start_time, @end_time)
    @table_cols = table_columns(@table_type)

    data = fetch_all_data
    timeseries_data = data[:timeseries]
    summary_data = data[:summary]

    summary = calculate_summary(timeseries_data, summary_data)
    overview = generate_overview(summary)

    {
      time_window: build_time_window(@start_time, @end_time, bucket_minutes: @bucket_minutes || 1),
      filters: build_filters_info,
      summary: summary,
      overview: overview,
      timeseries: timeseries_data
    }
  end

  private

  def fetch_all_data
    sql = build_combined_query
    result = client.select_all(sql)

    # Separate timeseries and summary data
    timeseries_rows = result.select { |row| row["query_type"] == "timeseries" }
    summary_row = result.find { |row| row["query_type"] == "summary" } || {}

    {
      timeseries: process_timeseries_result(timeseries_rows),
      summary: summary_row
    }
  end

  def build_combined_query
    filters = build_sql_filters.join(" AND ")

    # Build timeseries part
    timeseries_fields = build_timeseries_select_fields
    timeseries_group_by = @bucket_minutes ? "GROUP BY time_bucket" : ""

    # Build summary part
    summary_fields = build_summary_select_fields

    <<~SQL.squish
      SELECT 'timeseries' AS query_type, #{timeseries_fields}
      FROM #{@table_cols[:table]}
      WHERE #{filters}
      #{timeseries_group_by}

      UNION ALL

      SELECT 'summary' AS query_type, #{summary_fields}
      FROM #{@table_cols[:table]}
      WHERE #{filters}

      ORDER BY query_type, time_bucket DESC
    SQL
  end

  def build_timeseries_select_fields
    if @bucket_minutes
      bucket_seconds = @bucket_minutes * 60
      time_bucket = "toStartOfInterval(ts, INTERVAL #{bucket_seconds} second) AS time_bucket"
      aggregation_fields = build_timeseries_aggregations
    else
      time_bucket = "ts AS time_bucket"
      aggregation_fields = build_raw_fields
    end

    nulls = [ "toUInt64(0) AS total_samples", "toUInt64(0) AS total_endpoints", "toUInt64(0) AS total_devices", "toUInt64(0) AS total_hosts", "toUInt64(0) AS total_regions", "toUInt64(0) AS total_isps", "toUInt64(0) AS total_location_networks", "toUInt64(0) AS total_router_inventories" ]

    ([ time_bucket ] + aggregation_fields + nulls).join(", ")
  end

  def build_summary_select_fields
    time_bucket_null = "toDateTime('1970-01-01 00:00:00', 'UTC') AS time_bucket"
    summary_fields = build_summary_aggregation_fields
    timeseries_nulls = [
      "toFloat64(0) AS avg_latency_ms",
      "toUInt64(0) AS sample_count",
      "toUInt64(0) AS good_count",
      "toUInt64(0) AS warning_count",
      "toUInt64(0) AS critical_count",
      "toUInt64(0) AS down_count"
    ]

    ([ time_bucket_null ] + timeseries_nulls + summary_fields).join(", ")
  end

  def build_timeseries_aggregations
    if @table_type == :rollup
      [
        "toFloat64(sum(sum_latency) / sum(samples)) AS avg_latency_ms",
        "sum(samples) AS sample_count",
        "sum(good_count) AS good_count",
        "sum(warning_count) AS warning_count",
        "sum(critical_count) AS critical_count",
        "sum(down_count) AS down_count"
      ]
    else
      [
        "toFloat64(avg(latency_ms)) AS avg_latency_ms",
        "count(*) AS sample_count",
        "countIf(status = 1) AS good_count",
        "countIf(status = 2) AS warning_count",
        "countIf(status = 3) AS critical_count",
        "countIf(status = 4) AS down_count"
      ]
    end
  end

  def build_summary_aggregation_fields
    if @table_type == :rollup
      [
        "sum(samples) AS total_samples",
        "COUNT(DISTINCT endpoint_id) AS total_endpoints",
        "COUNT(DISTINCT device_id) AS total_devices",
        "COUNT(DISTINCT host) AS total_hosts",
        "COUNT(DISTINCT region) AS total_regions",
        "COUNT(DISTINCT isp) AS total_isps",
        "COUNT(DISTINCT location_network_id) AS total_location_networks",
        "COUNT(DISTINCT router_inventory_id) AS total_router_inventories"
      ]
    else
      [
        "count(*) AS total_samples",
        "COUNT(DISTINCT endpoint_id) AS total_endpoints",
        "COUNT(DISTINCT device_id) AS total_devices",
        "COUNT(DISTINCT host) AS total_hosts",
        "COUNT(DISTINCT region) AS total_regions",
        "COUNT(DISTINCT isp) AS total_isps",
        "COUNT(DISTINCT location_network_id) AS total_location_networks",
        "COUNT(DISTINCT router_inventory_id) AS total_router_inventories"
      ]
    end
  end

  def build_raw_fields
    if @table_type == :rollup
      [
        "toFloat64(sum_latency / samples) AS avg_latency_ms",
        "samples AS sample_count",
        "good_count AS good_count",
        "warning_count AS warning_count",
        "critical_count AS critical_count",
        "down_count AS down_count"
      ]
    else
      [
        "toFloat64(latency_ms) AS avg_latency_ms",
        "toUInt64(1) AS sample_count",
        "if(status = 1, toUInt64(1), toUInt64(0)) AS good_count",
        "if(status = 2, toUInt64(1), toUInt64(0)) AS warning_count",
        "if(status = 3, toUInt64(1), toUInt64(0)) AS critical_count",
        "if(status = 4, toUInt64(1), toUInt64(0)) AS down_count"
      ]
    end
  end

  def sanitize_sql_value(value)
    return "" unless value
    value.to_s.gsub("'", "''")
  end

  def build_sql_filters
    base_filters = super(:org_id, :host, :endpoint_id, :device_id, :isp, :region, :location_id, :router_id)

    time_filters = [
      "ts >= '#{@start_time.utc.strftime('%Y-%m-%d %H:%M:%S')}'",
      "ts <= '#{@end_time.utc.strftime('%Y-%m-%d %H:%M:%S')}'"
    ]

    base_filters + time_filters
  end

  def process_timeseries_result(result)
    result.filter_map do |row|
      timestamp = parse_time_utc(row["time_bucket"])
      next unless timestamp

      avg_latency = safe_to_f(row["avg_latency_ms"])

      status = determine_status_from_counts(
        row["good_count"].to_i,
        row["warning_count"].to_i,
        row["critical_count"].to_i,
        row["down_count"].to_i
      )

      # Apply sites_type filter if specified
      next unless matches_sites_type?(status)

      {
        timestamp: timestamp,
        time_ago: calculate_time_ago(timestamp),
        avg_latency_ms: avg_latency.round(2),
        sample_count: safe_to_i(row["sample_count"]),
        status: status
      }
    end
  end

  def safe_to_f(value)
    value.to_f
  rescue
    0.0
  end

  def safe_to_i(value)
    value.to_i
  rescue
    0
  end

  def matches_sites_type?(status)
    return true unless @sites_type.present?

    case @sites_type.downcase
    when "good"
      status == "good"
    when "warning"
      status == "warning"
    when "critical"
      status == "critical"
    when "down"
      status == "down"
    else
      true
    end
  end

  def calculate_summary(timeseries_data, summary_data)
    total_points = timeseries_data.size
    status_counts = count_status_points(timeseries_data)

    {
      total_data_points: total_points,
      good_points: status_counts[:good],
      warning_points: status_counts[:warning],
      critical_points: status_counts[:critical],
      down_points: status_counts[:down],
      good_percentage: calculate_percentage(status_counts[:good], total_points),
      warning_percentage: calculate_percentage(status_counts[:warning], total_points),
      critical_percentage: calculate_percentage(status_counts[:critical], total_points),
      down_percentage: calculate_percentage(status_counts[:down], total_points),
      total_samples: summary_data["total_samples"]&.to_i || 0,
      endpoint_count: summary_data["total_endpoints"]&.to_i || 0,
      device_count: summary_data["total_devices"]&.to_i || 0,
      host_count: summary_data["total_hosts"]&.to_i || 0,
      region_count: summary_data["total_regions"]&.to_i || 0,
      isp_count: summary_data["total_isps"]&.to_i || 0,
      location_network_count: summary_data["total_location_networks"]&.to_i || 0,
      router_inventory_count: summary_data["total_router_inventories"]&.to_i || 0,
      average_latency_ms: calculate_average(timeseries_data, :avg_latency_ms)
    }
  end

  def count_status_points(timeseries_data)
    good_points = timeseries_data.count { |d| d[:status] == "good" }
    warning_points = timeseries_data.count { |d| d[:status] == "warning" }
    critical_points = timeseries_data.count { |d| d[:status] == "critical" }
    down_points = timeseries_data.count { |d| d[:status] == "down" }

    { good: good_points, warning: warning_points, critical: critical_points, down: down_points }
  end

  def calculate_percentage(count, total)
    return 0 if total.zero?
    ((count.to_f / total) * 100).round(1)
  end

  def calculate_average(timeseries_data, field)
    values = timeseries_data.map { |d| d[field] }.compact
    return 0.0 if values.empty?
    (values.sum / values.size.to_f).round(2)
  end

  def generate_overview(summary)
    return "No data available for analysis" if summary[:total_data_points] == 0

    down_pct = summary[:down_percentage] || 0
    critical_pct = summary[:critical_percentage] || 0
    warning_pct = summary[:warning_percentage] || 0
    good_pct = summary[:good_percentage] || 0

    counts_desc = build_counts_description(summary)

    generate_performance_message(counts_desc, down_pct, critical_pct, warning_pct, good_pct)
  end

  def build_counts_description(summary)
    parts = []
    parts << "#{summary[:endpoint_count]} endpoint#{'s' if summary[:endpoint_count] != 1}" if summary[:endpoint_count] > 0
    parts << "#{summary[:device_count]} device#{'s' if summary[:device_count] != 1}" if summary[:device_count] > 0
    parts << "#{summary[:host_count]} host#{'s' if summary[:host_count] != 1}" if summary[:host_count] > 0
    parts << "#{summary[:region_count]} region#{'s' if summary[:region_count] != 1}" if summary[:region_count] > 0
    parts << "#{summary[:isp_count]} ISP#{'s' if summary[:isp_count] != 1}" if summary[:isp_count] > 0
    parts << "#{summary[:location_network_count]} location#{'s' if summary[:location_network_count] != 1}" if summary[:location_network_count] > 0

    parts.any? ? "Analysis across #{parts.join(', ')}" : "Analysis with no additional data"
  end

  def generate_performance_message(counts_desc, down_pct, critical_pct, warning_pct, good_pct)
    if down_pct >= 50
      "#{counts_desc} shows major performance issues with #{down_pct}% of time periods affected."
    elsif critical_pct >= 20
      "#{counts_desc} has intermittent performance issues affecting #{critical_pct}% of time periods."
    elsif warning_pct >= 30
      "#{counts_desc} shows poor performance with #{warning_pct}% of periods degraded."
    else
      "#{counts_desc} demonstrates good performance with #{good_pct}% of periods showing fast response times."
    end
  end

  def build_filters_info
    {
      host: @host,
      endpoint_id: @endpoint_id,
      device_id: @device_id,
      isp: @isp,
      region: @region,
      location_id: @location_id,
      router_id: @router_id,
      sites_type: @sites_type
    }.compact
  end
end
