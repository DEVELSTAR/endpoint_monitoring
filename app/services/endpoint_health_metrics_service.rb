class EndpointHealthMetricsService
  include ClickhouseClient
  include ClickhouseTableSelector
  include SqlFilterBuilder
  include UtcTimeParser
  include StatusClassifier

  # Group by field mappings for ClickHouse queries
  GROUP_BY_FIELDS = {
    "endpoint_id" => { field: "endpoint_id", label: :endpoint_id },
    "host" => { field: "host", label: :host },
    "device_id" => { field: "device_id", label: :device_id },
    "region" => { field: "region", label: :region },
    "location_id" => { field: "location_network_id", label: :location_network_id },
    "router_id" => { field: "router_inventory_id", label: :router_inventory_id },
    "isp" => { field: "isp", label: :isp },
    "isp_region" => { field: "concat(isp, ' - ', region)", label: :isp_region }
  }.freeze

  def initialize(params)
    @org_id = params[:org_id]
    start_t = params[:start_time].presence || 24.hours.ago.utc
    end_t = params[:end_time].presence || Time.current.utc

    @start_time = parse_time_utc(start_t, Time.current.utc)
    @end_time = parse_time_utc(end_t, Time.current.utc)
    @group_by = params[:group_by] || "endpoint_id"

    # Filters
    @filters = {
      host: params[:host],
      endpoint_id: params[:endpoint_id],
      isp: params[:isp],
      region: params[:region],
      location_id: params[:location_id],
      device_id: params[:device_id],
      router_id: params[:router_id]
    }.compact

    @sites_type = params[:sites_type]
  end

  def call
    table_type = select_table(@start_time, @end_time)
    metrics = fetch_aggregated_metrics(table_type)

    # Compute status for each group
    metrics_with_status = metrics.map do |row|
      status = compute_status(row)
      row.merge(status: status)
    end

    # Apply sites_type filter if specified
    metrics_with_status = filter_by_sites_type(metrics_with_status) if @sites_type

    build_response(metrics_with_status)
  end

  private

  def fetch_aggregated_metrics(table_type)
    group_config = GROUP_BY_FIELDS[@group_by] || GROUP_BY_FIELDS["endpoint_id"]
    group_field = group_config[:field]

    if table_type == :rollup
      fetch_from_rollup(group_field)
    else
      fetch_from_raw(group_field)
    end
  end

  def fetch_from_raw(group_field)
    # When grouping by endpoint_id, use group_key directly; otherwise use any()
    endpoint_id_select = if @group_by == "endpoint_id"
                           "group_key AS first_endpoint_id"
    else
                           "any(endpoint_id) AS first_endpoint_id"
    end

    query = <<~SQL
      SELECT
        #{group_field} AS group_key,
        #{endpoint_id_select},
        count(DISTINCT endpoint_id) AS endpoint_count,
        count(DISTINCT device_id) AS device_count,
        count(DISTINCT location_network_id) AS location_count,
        count(DISTINCT region) AS region_count,
        count(DISTINCT isp) AS isp_count,
        count(DISTINCT router_inventory_id) AS router_count,
        round(avg(latency_ms), 2) AS avg_latency_ms,
        countIf(status = 1) AS good_count,
        countIf(status = 2) AS warning_count,
        countIf(status = 3) AS critical_count,
        countIf(status = 4) AS down_count,
        count() AS sample_count
      FROM router_metrics_raw
      WHERE #{build_where_clause}
      GROUP BY group_key
      ORDER BY group_key
    SQL

    client.select_all(query)
  end

  def fetch_from_rollup(group_field)
    # When grouping by endpoint_id, use group_key directly; otherwise use any()
    endpoint_id_select = if @group_by == "endpoint_id"
                           "group_key AS first_endpoint_id"
    else
                           "any(endpoint_id) AS first_endpoint_id"
    end

    query = <<~SQL
      SELECT
        #{group_field} AS group_key,
        #{endpoint_id_select},
        count(DISTINCT endpoint_id) AS endpoint_count,
        count(DISTINCT device_id) AS device_count,
        count(DISTINCT location_network_id) AS location_count,
        count(DISTINCT region) AS region_count,
        count(DISTINCT isp) AS isp_count,
        count(DISTINCT router_inventory_id) AS router_count,
        round(sum(sum_latency) / nullIf(sum(samples), 0), 2) AS avg_latency_ms,
        sum(good_count) AS good_count,
        sum(warning_count) AS warning_count,
        sum(critical_count) AS critical_count,
        sum(down_count) AS down_count,
        sum(samples) AS sample_count
      FROM router_metrics_rollup
      WHERE #{build_where_clause} AND samples > 0
      GROUP BY group_key
      ORDER BY group_key
    SQL

    client.select_all(query)
  end

  def build_where_clause
    conditions = [ "org_id = '#{@org_id}'" ]
    conditions << "ts BETWEEN parseDateTimeBestEffort('#{@start_time.utc}') AND parseDateTimeBestEffort('#{@end_time.utc}')"

    # Apply filters
    conditions << "host ILIKE '%#{@filters[:host]}%'" if @filters[:host]
    conditions << "endpoint_id = '#{@filters[:endpoint_id]}'" if @filters[:endpoint_id]
    conditions << "isp ILIKE '%#{@filters[:isp]}%'" if @filters[:isp]
    conditions << "region ILIKE '%#{@filters[:region]}%'" if @filters[:region]
    conditions << "location_network_id = '#{@filters[:location_id]}'" if @filters[:location_id]
    conditions << "device_id = '#{@filters[:device_id]}'" if @filters[:device_id]
    conditions << "router_inventory_id = '#{@filters[:router_id]}'" if @filters[:router_id]

    conditions.join(" AND ")
  end

  def compute_status(row)
    determine_status_from_counts(
      row["good_count"].to_i,
      row["warning_count"].to_i,
      row["critical_count"].to_i,
      row["down_count"].to_i
    )
  end

  def filter_by_sites_type(metrics)
    status_map = { "good" => "good", "critical" => "critical", "down" => "down" }
    target_status = status_map[@sites_type] || @sites_type

    metrics.select { |m| m[:status] == target_status }
  end

  def build_response(metrics)
    group_config = GROUP_BY_FIELDS[@group_by] || GROUP_BY_FIELDS["endpoint_id"]
    label = group_config[:label]

    good_count = metrics.count { |m| m[:status] == "good" }
    down_count = metrics.count { |m| m[:status] == "down" }
    critical_count = metrics.count { |m| m[:status] == "critical" }

    {
      time_window: {
        start_time: @start_time.iso8601,
        end_time: @end_time.iso8601
      },
      group_by: @group_by,
      summary: {
        total: metrics.size,
        good: good_count,
        critical: critical_count,
        down: down_count
      },
      metrics: metrics.map { |m| format_metric(m, label) }
    }
  end

  def format_metric(row, label)
    {
      label => row["group_key"],
      endpoint_count: row["endpoint_count"].to_i,
      device_count: row["device_count"].to_i,
      location_count: row["location_count"].to_i,
      region_count: row["region_count"].to_i,
      isp_count: row["isp_count"].to_i,
      router_count: row["router_count"].to_i,
      avg_latency_ms: row["avg_latency_ms"].to_f,
      sample_count: row["sample_count"].to_i,
      status: row[:status]
    }
  end
end
