# app/services/site_distribution_service.rb
# Service for site-level analysis
# Provides site distribution based on majority vote of endpoints within each site
# Shows distribution of sites across different latency ranges
class SiteDistributionService
  include ClickhouseClient
  include StatusClassifier
  include ClickhouseTableSelector
  include SqlFilterBuilder
  include TimeAgoCalculator

  DEFAULT_BUCKET_SIZE = 20
  SITE_STATUS_MAPPING = {
    "good" => :good,
    "critical" => :critical,
    "down" => :down
  }.freeze

  def initialize(org_id:, start_time:, end_time:, group_by: "endpoint_id", host: nil, endpoint_id: nil, isp: nil,
                 region: nil, location_id: nil, device_id: nil, router_id: nil, sites_type: nil, bucket_size: nil)
    @org_id       = org_id
    @group_by     = group_by || "endpoint_id"
    @start_time   = start_time
    @end_time     = end_time
    @bucket_size  = (bucket_size&.to_i || DEFAULT_BUCKET_SIZE)

    # Filter support
    @host         = host         # hostname filter
    @endpoint_id  = endpoint_id  # specific endpoint
    @isp          = isp
    @region       = region       # region name (like Delhi)
    @location_id  = location_id  # location_network_id
    @device_id    = device_id    # mac address
    @router_id    = router_id    # router_inventory_id
    @sites_type   = sites_type   # good/critical/down filter
  end

  def call
    # Single data fetch to avoid duplication
    @grouped_data = get_grouped_data_with_endpoint_classification
    filtered_data = apply_sites_type_filter(@grouped_data)

    {
      time_window: build_time_window(@start_time, @end_time),
      group_by: @group_by,
      bucket_size: @bucket_size,
      summary: calculate_summary(filtered_data),
      distribution: calculate_distribution(filtered_data)
    }
  end

  private

  # Normalize sites_type parameter
  def normalize_sites_type(sites_type)
    return nil unless sites_type
    SITE_STATUS_MAPPING[sites_type.downcase] || sites_type.to_sym
  end

  # Apply sites_type filter to grouped data (extracted to reduce duplication)
  def apply_sites_type_filter(grouped_data)
    return grouped_data unless @sites_type

    target_status = normalize_sites_type(@sites_type)
    grouped_data.select { |_group_key, group_data| group_data[:status] == target_status }
  end

  # Calculate summary statistics for grouped data
  def calculate_summary(filtered_data = nil)
    # Support both new parameter-based and old instance variable-based calls
    filtered_data ||= apply_sites_type_filter(@grouped_data || get_grouped_data_with_endpoint_classification)

    status_counts = filtered_data.values.group_by { |item| item[:status] }.transform_values(&:count)

    # Fixed keys for summary regardless of group_by
    {
      count: filtered_data.size,
      good: status_counts[:good] || 0,
      critical: status_counts[:critical] || 0,
      down: status_counts[:down] || 0
    }
  end

  # Calculate distribution of grouped items across latency ranges
  def calculate_distribution(filtered_data = nil)
    # Support both new parameter-based and old instance variable-based calls
    filtered_data ||= apply_sites_type_filter(@grouped_data || get_grouped_data_with_endpoint_classification)

    # Fixed key for distribution regardless of group_by
    buckets = Hash.new do |h, k|
      h[k] = {
        latency_range: k,
        latency_bucket: k.split("-").first.to_i,
        count: 0,
        good: 0,
        critical: 0,
        down: 0
      }
    end

    filtered_data.each_value do |group_data|
      bucket_key = calculate_bucket_key(group_data[:avg_latency])
      buckets[bucket_key][:count] += 1
      status = group_data[:status]
      buckets[bucket_key][status] += 1 if status && buckets[bucket_key].key?(status)
    end

    unless buckets.empty?
      max_bucket = buckets.values.map { |b| b[:latency_bucket] }.max

      (0..max_bucket).step(@bucket_size) do |bucket_val|
        bucket_key = "#{bucket_val}-#{bucket_val + @bucket_size - 1}ms"
        buckets[bucket_key] # implicitly create if missing
      end
    end

    buckets.values.sort_by { |bucket| bucket[:latency_bucket] }
  end

  # Calculate bucket key for a given latency
  def calculate_bucket_key(avg_latency)
    bucket_start = (avg_latency / @bucket_size).floor * @bucket_size
    bucket_end = bucket_start + @bucket_size - 1
    "#{bucket_start.to_i}-#{bucket_end.to_i}ms"
  end

  # Get grouped data with endpoint classification and majority vote
  def get_grouped_data_with_endpoint_classification
    table_type = select_table(@start_time, @end_time)
    results = execute_endpoint_query(table_type)
    return {} if results.empty?

    build_grouped_data(results, table_type)
  end

  # Execute the appropriate SQL query based on table type
  def execute_endpoint_query(table_type)
    cols = table_columns(table_type)
    sql_filters = build_sql_filters
    sql = build_sql_query(table_type, cols, sql_filters)
    client.select_all(sql).to_a
  end

  # Build SQL query based on table type and group_by
  def build_sql_query(table_type, cols, sql_filters)
    base_where = "#{sql_filters.join(' AND ')} AND ts BETWEEN parseDateTimeBestEffort('#{@start_time}') AND parseDateTimeBestEffort('#{@end_time}')"
    group_cols = get_group_columns

    # Handle GROUP BY and ORDER BY clauses
    if @group_by == "endpoint_id"
      group_by_clause = "endpoint_id, host"
      order_by_clause = "endpoint_id, host"
      select_clause = "endpoint_id, host"
    else
      group_by_clause = "endpoint_id, host, #{group_cols[:group]}"
      order_by_clause = "#{group_cols[:group]}, endpoint_id, host"
      select_clause = "endpoint_id, host, #{group_cols[:select]}"
    end

    if table_type == :rollup
      <<~SQL.squish
        SELECT #{select_clause},
               sum(sum_latency) / sum(samples) AS avg_latency,
               sum(good_count) AS good_count,
               sum(warning_count) AS warning_count,
               sum(critical_count) AS critical_count,
               sum(down_count) AS down_count,
               sum(samples) AS total_samples
        FROM #{cols[:table]}
        WHERE #{base_where} AND samples > 0
        GROUP BY #{group_by_clause}
        ORDER BY #{order_by_clause}
      SQL
    else
      <<~SQL.squish
        SELECT #{select_clause},
               avg(latency_ms) AS avg_latency,
               countIf(status = 1) AS good_count,
               countIf(status = 2) AS warning_count,
               countIf(status = 3) AS critical_count,
               countIf(status = 4) AS down_count,
               count(*) AS total_samples
        FROM #{cols[:table]}
        WHERE #{base_where}
        GROUP BY #{group_by_clause}
        ORDER BY #{order_by_clause}
      SQL
    end
  end

  # Build grouped data from query results
  def build_grouped_data(results, table_type)
    grouped_data = Hash.new { |h, k| h[k] = { endpoints: [], total_latency: 0.0, total_samples: 0 } }

    results.each do |row|
      endpoint_id = row["endpoint_id"].to_i

      samples = row["total_samples"].to_i
      next if samples.zero?

      group_key = extract_group_key(row)
      avg_latency = row["avg_latency"].to_f

      endpoint_status = determine_status_from_counts(
        row["good_count"].to_i,
        row["warning_count"].to_i,
        row["critical_count"].to_i,
        row["down_count"].to_i
      )

      add_endpoint_to_group(grouped_data[group_key], endpoint_id, row["host"], endpoint_status, avg_latency, samples)
    end

    finalize_grouped_data(grouped_data)
  end

  # Add endpoint data to group
  def add_endpoint_to_group(group_data, endpoint_id, host, endpoint_status, avg_latency, samples)
    group_data[:endpoints] << {
      endpoint_id: endpoint_id,
      host: host || "unknown",
      status: endpoint_status,
      avg_latency: avg_latency,
      samples: samples
    }

    # Accumulate weighted metrics for group average
    group_data[:total_latency] += avg_latency * samples
    group_data[:total_samples] += samples
  end

  # Finalize grouped data with calculated metrics
  def finalize_grouped_data(grouped_data)
    grouped_data.each_value do |group_data|
      group_data[:avg_latency] = group_data[:total_samples] > 0 ?
        group_data[:total_latency] / group_data[:total_samples] : 0.0

      endpoint_statuses = group_data[:endpoints].map { |ep| ep[:status] }
      group_data[:status] = determine_group_status_by_majority(endpoint_statuses)
      group_data[:endpoint_count] = group_data[:endpoints].size
    end

    grouped_data
  end

  # Determine group status by majority vote of endpoints (simplified logic)
  def determine_group_status_by_majority(endpoint_statuses)
    return :down if endpoint_statuses.empty?

    status_counts = endpoint_statuses.tally
    total_endpoints = endpoint_statuses.size
    majority_threshold = total_endpoints / 2.0

    # Check for majority in order of severity
    return :down if (status_counts["down"] || 0) > majority_threshold
    return :good if (status_counts["good"] || 0) > majority_threshold

    # Default to critical for ties or when critical + good > down but no clear majority
    :critical
  end

  # Get group columns for SQL query based on group_by parameter
  def get_group_columns
    case @group_by
    when "endpoint_id"
      { select: "endpoint_id", group: "endpoint_id" }
    when "host"
      { select: "endpoint_id, host", group: "endpoint_id, host" }
    when "device_id"
      { select: "device_id", group: "device_id" }
    when "location_id"
      { select: "location_network_id", group: "location_network_id" }
    when "router_id"
      { select: "router_inventory_id", group: "router_inventory_id" }
    when "region"
      { select: "region", group: "region" }
    when "isp"
      { select: "isp", group: "isp" }
    when "isp_region"
      { select: "isp, region", group: "isp, region" }
    else
      # Default to endpoint_id if invalid group_by
      { select: "endpoint_id", group: "endpoint_id" }
    end
  end

  # Extract group key from row based on group_by parameter
  def extract_group_key(row)
    case @group_by
    when "endpoint_id"
      row["endpoint_id"].to_s
    when "host"
      "#{row['endpoint_id']}_#{row['host']}"
    when "device_id"
      row["device_id"].to_s
    when "location_id"
      row["location_network_id"].to_s
    when "router_id"
      row["router_inventory_id"].to_s
    when "region"
      row["region"].to_s
    when "isp"
      row["isp"].to_s
    when "isp_region"
      "#{row['isp']}_#{row['region']}"
    else
      row["endpoint_id"].to_s
    end
  end

  # Get appropriate count key for summary based on group_by
  def get_count_key
    case @group_by
    when "endpoint_id"
      "endpoints"
    when "host"
      "hosts"
    when "device_id"
      "devices"
    when "location_id"
      "sites"
    when "router_id"
      "routers"
    when "region"
      "regions"
    when "isp"
      "isps"
    when "isp_region"
      "isp_regions"
    else
      "endpoints"
    end
  end

  def build_sql_filters
    super(:org_id, :host, :region, :isp, :endpoint_id, :location_id, :device_id, :router_id)
  end
end
