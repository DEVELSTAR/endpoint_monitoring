class EndpointMetricsService
  include ClickhouseClient
  include ClickhouseTableSelector
  include TimeAgoCalculator
  include SqlFilterBuilder

  attr_reader :org_id, :group_by, :start_time, :end_time, :endpoint_id, :host, :region, :location_id,
              :router_id, :isp, :device_id, :sites_type, :page, :per_page

  def initialize(org_id:, start_time:, end_time:, group_by: nil, endpoint_id: nil,
                 host: nil, region: nil, location_id: nil, router_id: nil, isp: nil,
                 device_id: nil, sites_type: nil, page: nil, per_page: nil)
    @org_id = org_id
    @group_by = group_by
    @start_time = start_time
    @end_time = end_time
    @endpoint_id = endpoint_id
    @host = host
    @region = region
    @location_id = location_id
    @router_id = router_id
    @isp = isp
    @device_id = device_id
    @sites_type = sites_type
    @page = (page.to_i > 0 ? page.to_i : 1)
    @per_page = (per_page.to_i > 0 ? per_page.to_i : 10)
  end

  def call
    validate_parameters!

    # Get endpoint info if endpoint_id is provided
    endpoint_info = get_endpoint_info if endpoint_id.present?
    # Determine table and get metrics
    cols = table_columns(:raw)

    if group_by == "endpoint_id" && endpoint_id.present?
      # Single endpoint detailed metrics
      metrics, summary, total_count = get_single_endpoint_metrics(cols, endpoint_info)
    else
      # Grouped metrics
      metrics, summary, total_count = get_grouped_metrics(cols)
    end

    # Build response
    response = {
      group_by: group_by,
      time_window: build_time_window(start_time, end_time),
      summary: summary,
      metrics: metrics,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }

    # Add endpoint info for single endpoint queries
    response[:endpoint] = endpoint_info if endpoint_info

    response
  end

  private

  def validate_parameters!
    raise ArgumentError, "org_id is required" unless org_id.present?

    valid_groups = %w[endpoint_id host device_id region location_id router_id isp isp_region]
    unless valid_groups.include?(group_by)
      raise ArgumentError, "Invalid group_by. Options: #{valid_groups.join(', ')}"
    end

    if group_by == "endpoint_id" && endpoint_id.blank?
      raise ArgumentError, "endpoint_id is required when group_by is endpoint_id"
    end
  end

  def get_endpoint_info
    endpoint = EndpointMonitoringEndpoint.find_by(id: endpoint_id)

    return nil unless endpoint

    {
      id: endpoint.id,
      name: endpoint.name,
      host: endpoint.host,
      monitoring_mode: endpoint.monitoring_mode
    }
  end

  def get_single_endpoint_metrics(cols, endpoint_info)
    # Build filters
    sql_filters = build_sql_filters
    offset = (page - 1) * per_page

    # Get total count
    count_sql = build_count_query(cols, sql_filters)
    total_count = client.select_all(count_sql).first["total"].to_i

    # Get metrics
    metrics_sql = build_single_endpoint_query(cols, sql_filters, offset)
    rows = client.select_all(metrics_sql)

    # Process results
    metrics = process_single_endpoint_rows(rows)
    summary = calculate_single_endpoint_summary(metrics, endpoint_info)

    [ metrics, summary, total_count ]
  end

  def get_grouped_metrics(cols)
    # Build filters
    sql_filters = build_sql_filters
    offset = (page - 1) * per_page

    # Get total count for groups
    count_sql = build_grouped_count_query(cols, sql_filters)
    total_count = client.select_all(count_sql).first["total"].to_i

    # Get grouped metrics
    metrics_sql = build_grouped_query(cols, sql_filters, offset)
    rows = client.select_all(metrics_sql)

    # Process results
    metrics = process_grouped_rows(rows)
    summary = calculate_grouped_summary(metrics)

    [ metrics, summary, total_count ]
  end

  def build_sql_filters
    super(:org_id, :endpoint_id, :host, :region, :location_id, :router_id, :isp, :device_id)
  end

  def get_group_columns
    case group_by
    when "endpoint_id"
      { group_fields: "endpoint_id", select_fields: "endpoint_id, host" }
    when "host"
      { group_fields: "host", select_fields: "host, any(endpoint_id) as endpoint_id" }
    when "device_id"
      { group_fields: "device_id", select_fields: "device_id" }
    when "region"
      { group_fields: "region", select_fields: "region, any(location_network_id) as location_network_id" }
    when "location_id"
      { group_fields: "location_network_id", select_fields: "location_network_id, any(region) as region" }
    when "router_id"
      { group_fields: "router_inventory_id", select_fields: "router_inventory_id" }
    when "isp"
      { group_fields: "isp", select_fields: "isp" }
    when "isp_region"
      { group_fields: "isp, region", select_fields: "isp, region, any(location_network_id) as location_network_id" }
    else
      { group_fields: "endpoint_id", select_fields: "endpoint_id, host" }
    end
  end

  def build_count_query(cols, sql_filters)
    <<~SQL.squish
      SELECT count(*) as total
      FROM #{cols[:table]}
      WHERE #{sql_filters.join(" AND ")}
        AND ts BETWEEN parseDateTimeBestEffort('#{start_time.iso8601}')
                                    AND parseDateTimeBestEffort('#{end_time.iso8601}')
    SQL
  end

  def build_grouped_count_query(cols, sql_filters)
    group_cols = get_group_columns

    <<~SQL.squish
      SELECT count(*) as total
      FROM (
        SELECT #{group_cols[:group_fields]}
        FROM #{cols[:table]}
        WHERE #{sql_filters.join(" AND ")}
          AND ts BETWEEN parseDateTimeBestEffort('#{start_time.iso8601}')
                                      AND parseDateTimeBestEffort('#{end_time.iso8601}')
        GROUP BY #{group_cols[:group_fields]}
      )
    SQL
  end

  def build_single_endpoint_query(cols, sql_filters, offset)
    <<~SQL.squish
      SELECT
        ts,
        latency_ms,
        region,
        location_network_id,
        router_inventory_id,
        isp,
        device_id,
        tcp_status,
        http_status,
        status
      FROM #{cols[:table]}
      WHERE #{sql_filters.join(" AND ")}
        AND ts BETWEEN parseDateTimeBestEffort('#{start_time.iso8601}')
                                    AND parseDateTimeBestEffort('#{end_time.iso8601}')
      ORDER BY ts DESC
      LIMIT #{per_page} OFFSET #{offset}
    SQL
  end

  def build_grouped_query(cols, sql_filters, offset)
    group_cols = get_group_columns

    <<~SQL.squish
      SELECT
        #{group_cols[:select_fields]},
        avg(latency_ms) as avg_latency_ms,
        count(*) as total_samples,
        min(ts) as first_seen,
        max(ts) as last_seen
      FROM #{cols[:table]}
      WHERE #{sql_filters.join(" AND ")}
        AND ts BETWEEN parseDateTimeBestEffort('#{start_time.iso8601}')
                                    AND parseDateTimeBestEffort('#{end_time.iso8601}')
      GROUP BY #{group_cols[:group_fields]}
      ORDER BY avg_latency_ms ASC
      LIMIT #{per_page} OFFSET #{offset}
    SQL
  end

  def process_single_endpoint_rows(rows)
    # Filter valid metrics
    valid_metrics = rows.select { |r| r["latency_ms"].to_f >= 0 }

    status_map = { 1 => "good", 2 => "warning", 3 => "critical", 4 => "down" }

    valid_metrics.map do |r|
      {
        timestamp: r["ts"],
        latency_ms: r["latency_ms"].to_f.round(2),
        time_ago: calculate_time_ago(r["ts"]),
        region: r["region"],
        location_id: r["location_network_id"],
        router_id: r["router_inventory_id"],
        isp: r["isp"],
        device_id: r["device_id"],
        status: status_map[r["status"].to_i] || "unknown",
        http_code: r["http_status"]
      }
    end
  end

  def process_grouped_rows(rows)
    rows.map do |r|
      base_metric = {
        avg_latency_ms: r["avg_latency_ms"].to_f.round(2),
        total_samples: r["total_samples"].to_i,
        first_seen: r["first_seen"],
        last_seen: r["last_seen"]
      }

      # Add group-specific fields
      case group_by
      when "endpoint_id"
        base_metric.merge(
          endpoint_id: r["endpoint_id"],
          host: r["host"]
        )
      when "host"
        base_metric.merge(
          host: r["host"],
          endpoint_id: r["endpoint_id"]
        )
      when "device_id"
        base_metric.merge(device_id: r["device_id"])
      when "region"
        base_metric.merge(
          region: r["region"],
          location_id: r["location_network_id"]
        )
      when "location_id"
        base_metric.merge(
          location_id: r["location_network_id"],
          region: r["region"]
        )
      when "router_id"
        base_metric.merge(router_id: r["router_inventory_id"])
      when "isp"
        base_metric.merge(isp: r["isp"])
      when "isp_region"
        base_metric.merge(
          isp: r["isp"],
          region: r["region"],
          location_id: r["location_network_id"]
        )
      else
        base_metric
      end
    end
  end

  def calculate_single_endpoint_summary(metrics, endpoint_info)
    total_samples = metrics.length
    return { total_samples: 0, uptime_pct: 0, avg_latency: 0 } if total_samples == 0

    uptime_count = metrics.count do |m|
      m[:status] != "down"
    end

    uptime_pct = total_samples > 0 ? ((uptime_count.to_f / total_samples) * 100).round(2) : 0
    avg_latency = (metrics.sum { |m| m[:latency_ms] } / total_samples).round(2)

    {
      total_samples: total_samples,
      uptime_pct: uptime_pct,
      avg_latency: avg_latency
    }
  end

  def calculate_grouped_summary(metrics)
    return { total_groups: 0, total_samples: 0, avg_latency: 0 } if metrics.empty?

    total_samples = metrics.sum { |m| m[:total_samples] }
    avg_latency = total_samples > 0 ? (metrics.sum { |m| m[:avg_latency_ms] * m[:total_samples] } / total_samples).round(2) : 0

    {
      total_groups: metrics.length,
      total_samples: total_samples,
      avg_latency: avg_latency
    }
  end
end
