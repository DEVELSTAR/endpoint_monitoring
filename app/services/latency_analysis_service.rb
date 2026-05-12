# app/services/latency_analysis_service.rb
# Optimized service that aggregates in ClickHouse but classifies with endpoint-specific thresholds
# Includes caching for improved performance

class LatencyAnalysisService
  include ClickhouseClient
  include ClickhouseTableSelector
  include SqlFilterBuilder
  include TimeAgoCalculator

  def initialize(org_id:, group_by:, start_time:, end_time:, host: nil, endpoint_id: nil,
                 isp: nil, region: nil, location_id: nil, device_id: nil, router_id: nil, sites_type: nil)
    @org_id = org_id
    @group_by = group_by
    @start_time = start_time
    @end_time = end_time
    @host = host
    @endpoint_id = endpoint_id
    @isp = isp
    @region = region
    @location_id = location_id
    @device_id = device_id
    @router_id = router_id
    @sites_type = sites_type
    @endpoints_cache = nil
  end

  def call
    table_type = select_table(@start_time, @end_time)
    cols = table_columns(table_type)

    # Build and execute query (get aggregated metrics)
    sql = build_query(table_type, cols)
    results = client.select_all(sql).to_a

    # Only load endpoints if grouping by endpoint_id (for metadata like group name and type)
    endpoints_map = load_endpoints_for_results(results)

    # Classify and format results
    data = classify_and_format_results(results, endpoints_map, table_type)

    {
      time_window: build_time_window(@start_time, @end_time),
      group_by: @group_by,
      response_efficiency: calculate_efficiency(data),
      data: data
    }
  end

  private

  def build_query(table_type, cols)
    filters = build_sql_filters
    group_col = get_group_column

    # Include regions array when grouping by endpoint_id
    regions_field = @group_by == "endpoint_id" ? "groupUniqArray(region) as regions," : ""

    # Query aggregates metrics
    <<~SQL.squish
      SELECT#{' '}
        #{group_col} as group_key,
        endpoint_id,
        #{regions_field}
        #{build_metrics_fields(table_type)}
      FROM #{cols[:table]}
      WHERE #{filters.join(' AND ')}
        AND ts BETWEEN parseDateTimeBestEffort('#{@start_time}')#{' '}
                   AND parseDateTimeBestEffort('#{@end_time}')
      GROUP BY group_key, endpoint_id
      ORDER BY group_key, endpoint_id
    SQL
  end

  def build_metrics_fields(table_type)
    if table_type == :rollup
      <<~SQL.squish
        avg(sum_latency / samples) as avg_latency_ms,
        sum(good_count) as good_count,
        sum(warning_count) as warning_count,
        sum(critical_count) as critical_count,
        sum(down_count) as down_count,
        sum(samples) as sample_count
      SQL
    else
      <<~SQL.squish
        avg(latency_ms) as avg_latency_ms,
        countIf(status = 1) as good_count,
        countIf(status = 2) as warning_count,
        countIf(status = 3) as critical_count,
        countIf(status = 4) as down_count,
        count() as sample_count,
        argMax(status, ts) as last_status
      SQL
    end
  end

  def build_sql_filters
    super(:org_id, :host, :region, :isp, :endpoint_id, :location_id, :device_id, :router_id)
  end

  def get_group_column
    case @group_by
    when "endpoint_id" then "endpoint_id"
    when "host" then "host"
    when "device_id" then "device_id"
    when "region" then "region"
    when "location_id" then "location_network_id"
    when "router_id" then "router_inventory_id"
    when "isp" then "isp"
    when "isp_region" then "concat(isp, '_', region)"
    else "endpoint_id"
    end
  end

  def load_endpoints_for_results(results)
    return {} unless @group_by == "endpoint_id"
    return @endpoints_cache if @endpoints_cache

    endpoint_ids = results.map { |r| r["endpoint_id"] }.compact.map(&:to_i).uniq
    return {} if endpoint_ids.empty?

    # Build cache key from sorted endpoint IDs
    cache_key = "endpoints:batch:#{endpoint_ids.sort.join(',')}"

    # Try to fetch from cache first (5 minute TTL)
    @endpoints_cache = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      # Cache miss - load from database
      Rails.logger.info "[Cache MISS] Loading #{endpoint_ids.size} endpoints from database"
      EndpointMonitoringEndpoint.includes(:endpoint_monitoring_group).where(id: endpoint_ids).index_by(&:id)
    end

    @endpoints_cache
  rescue TypeError, ArgumentError => e
    # Handle cache serialization errors (e.g., in tests with mock objects)
    Rails.logger.warn "[Cache ERROR] #{e.message}, falling back to direct query"
    @endpoints_cache = EndpointMonitoringEndpoint.includes(:endpoint_monitoring_group).where(id: endpoint_ids).index_by(&:id)
  end

  def classify_and_format_results(results, endpoints_map, table_type = :raw)
    # Group results by group_key
    grouped = results.group_by { |r| r["group_key"] }

    grouped.filter_map do |group_key, rows|
      group_metrics = {
        total_latency: 0,
        total_samples: 0,
        good_count: 0,
        warning_count: 0,
        critical_count: 0,
        down_count: 0
      }

      # Track last record status for temp_status (only for device_id grouping with raw table)
      last_status = nil

      rows.each do |row|
        avg_latency = row["avg_latency_ms"].to_f
        samples = row["sample_count"].to_i

        group_metrics[:good_count] += row["good_count"].to_i
        group_metrics[:warning_count] += row["warning_count"].to_i
        group_metrics[:critical_count] += row["critical_count"].to_i
        group_metrics[:down_count] += row["down_count"].to_i

        group_metrics[:total_latency] += avg_latency * samples
        group_metrics[:total_samples] += samples

        # Capture last record status (from argMax in query)
        last_status = row["last_status"] if row["last_status"]
      end

      next if group_metrics[:total_samples] == 0

      # Determine group status by counts
      group_status = determine_group_status(group_metrics)

      # Apply sites_type filter
      next unless passes_sites_type_filter?(group_status)

      # Calculate group averages
      avg_latency_ms = group_metrics[:total_samples] > 0 ?
        group_metrics[:total_latency] / group_metrics[:total_samples] : 0

      result = {
        @group_by.to_sym => group_key,
        avg_latency_ms: avg_latency_ms.round(2),
        sample_count: group_metrics[:total_samples],
        status: group_status
      }

      # Inject group name and monitoring mode when grouping strictly by endpoint
      if @group_by == "endpoint_id"
        endpoint = endpoints_map[group_key.to_i]
        if endpoint
          result[:host] = endpoint.host
          result[:group] = endpoint.endpoint_monitoring_group&.name
          result[:type] = endpoint.monitoring_mode
        end
        # Add regions array from ClickHouse query results
        result[:regions] = rows.first["regions"] || []
      end

      # Add temp_status for device_id grouping with raw table
      if @group_by == "device_id" && last_status
        result[:temp_status] = last_status.to_i == 4 ? "down" : "up"
      end

      result
    end
  end

  def determine_group_status(counts)
    total = counts[:good_count] + counts[:warning_count] + counts[:critical_count] + counts[:down_count]
    return :down if total == 0

    down_ratio = counts[:down_count].to_f / total
    critical_ratio = counts[:critical_count].to_f / total
    warning_ratio = counts[:warning_count].to_f / total

    # Majority vote logic: choose worst status in case of tie
    if down_ratio >= 0.5 && counts[:down_count] > 0
      :down
    elsif (down_ratio + critical_ratio) >= 0.5 && counts[:critical_count] > 0
      :critical
    elsif (down_ratio + critical_ratio + warning_ratio) > 0.5
      :warning
    else
      :good
    end
  end

  def passes_sites_type_filter?(status)
    return true unless @sites_type

    filter_status = case @sites_type.downcase
    when "good" then :good
    when "warning" then :warning
    when "critical" then :critical
    when "down" then :down
    else @sites_type.to_sym
    end

    status == filter_status
  end

  def calculate_efficiency(data)
    status_counts = data.each_with_object(Hash.new(0)) do |row, counts|
      counts[row[:status]] += 1
    end

    total = status_counts.values.sum
    return { good: 0, warning: 0, critical: 0, down: 0, total_count: 0 } if total.zero?

    {
      good: ((status_counts[:good].to_f / total) * 100).round(2),
      warning: ((status_counts[:warning].to_f / total) * 100).round(2),
      critical: ((status_counts[:critical].to_f / total) * 100).round(2),
      down: ((status_counts[:down].to_f / total) * 100).round(2),
      total_count: total
    }
  end
end
