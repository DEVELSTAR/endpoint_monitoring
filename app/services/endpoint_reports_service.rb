# app/services/endpoint_reports_service.rb
class EndpointReportsService
  include StatusClassifier
  include ClickhouseClient
  include ClickhouseTableSelector
  include SqlFilterBuilder

  def initialize(org_id:, start_time:, end_time:,
                 host: nil, endpoint_id: nil, device_id: nil, isp: nil, region: nil,
                 location_id: nil, router_id: nil, sites_type: nil, group_by: "endpoint_id")
    @org_id = org_id
    @start_time = start_time
    @end_time = end_time
    @group_by = group_by

    # Optional filters
    @host = host
    @endpoint_id = endpoint_id
    @device_id = device_id
    @isp = isp
    @region = region
    @location_id = location_id
    @router_id = router_id
    @sites_type = sites_type
  end

  def call
    table_type = select_table(@start_time, @end_time)
    table_cols = table_columns(table_type)

    bucket_minutes = calculate_bucket_minutes

    results = fetch_bucketed_data(table_type, table_cols, bucket_minutes)

    # Apply sites_type filtering and group_by logic using aggregated counts
    processed_data = process_data_by_group_and_filter(results)

    format_results(processed_data, bucket_minutes)
  end

  private

  def calculate_bucket_minutes
    duration_hours = (@end_time - @start_time).to_f / 1.hour

    if duration_hours.round <= 24
      120.to_i # 2 hours
    elsif duration_hours.round < 720 # 30 * 24
      1440.to_i # 1 day
    else
      10080.to_i # 1 week
    end
  end

  def build_sql_filters_with_time_range
    filters = build_sql_filters(:org_id, :host, :endpoint_id, :device_id, :isp, :region, :location_id, :router_id)
    filters << "ts BETWEEN parseDateTimeBestEffort('#{@start_time}') AND parseDateTimeBestEffort('#{@end_time}')"
    filters.join(" AND ")
  end

  def fetch_bucketed_data(table_type, table_cols, bucket_minutes)
    filters = build_sql_filters_with_time_range
    group_columns = get_group_columns

    # Query aggregates metrics per bucket per group to be classified in Ruby
    sql = <<~SQL.squish
      SELECT
        toStartOfInterval(ts, INTERVAL #{bucket_minutes} minute) AS time_bucket,
        #{group_columns[:select]},
        #{build_metrics_fields(table_type)}
      FROM #{table_cols[:table]}
      WHERE #{filters}
      GROUP BY time_bucket, #{group_columns[:group]}
      ORDER BY time_bucket, #{group_columns[:group]}
    SQL

    client.select_all(sql)
  end

  def build_metrics_fields(table_type)
    if table_type == :rollup
      <<~SQL.squish
        sum(good_count) as good_count,
        sum(warning_count) as warning_count,
        sum(critical_count) as critical_count,
        sum(down_count) as down_count
      SQL
    else
      <<~SQL.squish
        countIf(status = 1) as good_count,
        countIf(status = 2) as warning_count,
        countIf(status = 3) as critical_count,
        countIf(status = 4) as down_count
      SQL
    end
  end

  def format_results(classified_rows, bucket_minutes)
    # Global tracking across all time
    global_counts = { good: 0, critical: 0, down: 0 }

    # Group by time bucket
    grouped_by_time = classified_rows.group_by { |r| r[:time_bucket] }

    metrics = grouped_by_time.filter_map do |time_bucket, rows|
      bucket_counts = { good: 0, critical: 0, down: 0 }

      rows.each do |row_data|
        status = row_data[:status].to_sym

        # Merge warning into good
        status = :good if status == :warning

        if bucket_counts.key?(status)
          bucket_counts[status] += 1
          global_counts[status] += 1
        end
      end

      # Exclude bucket if no valid data
      total_in_bucket = bucket_counts.values.sum
      next if total_in_bucket == 0

      {
        time: Time.parse(time_bucket).utc.iso8601,
        good: ((bucket_counts[:good].to_f / total_in_bucket) * 100).round(2),
        critical: ((bucket_counts[:critical].to_f / total_in_bucket) * 100).round(2),
        down: ((bucket_counts[:down].to_f / total_in_bucket) * 100).round(2)
      }
    end

    total_global = global_counts.values.sum
    summary = {
      good: total_global > 0 ? ((global_counts[:good].to_f / total_global) * 100).round(2) : 0.0,
      critical: total_global > 0 ? ((global_counts[:critical].to_f / total_global) * 100).round(2) : 0.0,
      down: total_global > 0 ? ((global_counts[:down].to_f / total_global) * 100).round(2) : 0.0
    }

    {
      time_window: {
        start_time: @start_time.iso8601,
        end_time: @end_time.iso8601,
        bucket_minutes: bucket_minutes
      },
      group_by: @group_by,
      summary: summary,
      metrics: metrics
    }
  end

  def get_group_columns
    case @group_by
    when "host"
      { select: "host AS group_key, any(endpoint_id) AS endpoint_id", group: "host" }
    when "endpoint_id"
      { select: "endpoint_id AS group_key, endpoint_id", group: "endpoint_id" }
    when "device_id"
      { select: "device_id AS group_key, any(endpoint_id) AS endpoint_id", group: "device_id" }
    when "region"
      { select: "region AS group_key, any(endpoint_id) AS endpoint_id", group: "region" }
    when "location_id"
      { select: "location_network_id AS group_key, any(endpoint_id) AS endpoint_id", group: "location_network_id" }
    when "router_id"
      { select: "router_inventory_id AS group_key, any(endpoint_id) AS endpoint_id", group: "router_inventory_id" }
    when "isp"
      { select: "isp AS group_key, any(endpoint_id) AS endpoint_id", group: "isp" }
    when "isp_region"
      { select: "isp AS group_key_isp, region AS group_key_region, any(endpoint_id) AS endpoint_id", group: "isp, region" }
    else
      { select: "endpoint_id AS group_key, endpoint_id", group: "endpoint_id" }
    end
  end

  def get_group_key_from_row(row)
    case @group_by
    when "isp_region"
      isp = row["group_key_isp"] || row["isp"]
      region = row["group_key_region"] || row["region"]
      return nil if isp.blank? || region.blank?
      "#{isp}|#{region}"
    else
      row["group_key"] || row[@group_by]
    end
  end

  def get_group_display_name(row)
    case @group_by
    when "endpoint_id"
      { endpoint_id: row["endpoint_id"] }
    when "host"
      { host: row["group_key"] || row["host"] }
    when "device_id"
      { device_id: row["group_key"] || row["device_id"] }
    when "region"
      { region: row["group_key"] || row["region"] }
    when "location_id"
      { location_id: row["group_key"] || row["location_network_id"] }
    when "router_id"
      { router_id: row["group_key"] || row["router_inventory_id"] }
    when "isp"
      { isp: row["group_key"] || row["isp"] }
    when "isp_region"
      { isp: row["group_key_isp"] || row["isp"], region: row["group_key_region"] || row["region"] }
    else
      { endpoint_id: row["endpoint_id"] }
    end
  end

  def process_data_by_group_and_filter(results)
    # First, classify each row and determine if it passes sites_type filter
    classified_rows = []

    results.each do |row|
      group_key = get_group_key_from_row(row)
      next if group_key.blank?

      good_count = row["good_count"].to_i
      warning_count = row["warning_count"].to_i
      critical_count = row["critical_count"].to_i
      down_count = row["down_count"].to_i

      # Classify the performance based on counts
      status = determine_status_from_counts(good_count, warning_count, critical_count, down_count)

      # Apply sites_type filter
      next unless passes_sites_type_filter?(status)

      classified_rows << {
        time_bucket: row["time_bucket"],
        group_key: group_key,
        group_display: get_group_display_name(row),
        status: status,
        row: row
      }
    end

    classified_rows
  end

  def passes_sites_type_filter?(status)
    return true unless @sites_type.present?

    # Normalize status for comparison
    normalized_status = status.to_s.downcase

    # Map warning to good for sites_type comparison
    normalized_status = "good" if normalized_status == "warning"

    case @sites_type.to_s.downcase
    when "good"
      normalized_status == "good"
    when "critical"
      normalized_status == "critical"
    when "down"
      normalized_status == "down"
    else
      true
    end
  end
end
