# frozen_string_literal: true

# Service to get location-level status for a specific endpoint
# Shows whether the endpoint is up or down at each location based on threshold comparison
class EndpointLocationStatusService
  include ClickhouseClient
  include ClickhouseTableSelector
  include UtcTimeParser
  include StatusClassifier

  def initialize(params = {})
    @org_id = params[:org_id]
    @endpoint_id = params[:endpoint_id]
    @start_time = params[:start_time]
    @end_time = params[:end_time]
    @page = (params[:page] || 1).to_i
    @per_page = (params[:per_page] || 50).to_i
  end

  def call
    # Validate required parameters
    return error_response("endpoint_id is required") unless @endpoint_id.present?

    # Load endpoint configuration
    endpoint = EndpointMonitoringEndpoint.joins(:endpoint_monitoring_group)
                                          .where(id: @endpoint_id, endpoint_monitoring_groups: { organisation_id: @org_id })
                                          .first
    return error_response("Endpoint not found") unless endpoint

    # Select appropriate ClickHouse table
    @table_type = select_table(@start_time, @end_time)

    # Get location metrics for the endpoint
    location_metrics = fetch_location_metrics(endpoint)

    # Calculate summary statistics
    summary = calculate_summary(location_metrics)

    # Apply pagination
    total_count = location_metrics.size
    paginated_data = paginate_results(location_metrics)

    {
      time_window: {
        start_time: @start_time,
        end_time: @end_time,
        duration_hours: calculate_duration_hours
      },
      endpoint: {
        endpoint_id: endpoint.id,
        name: endpoint.name,
        monitoring_mode: endpoint.monitoring_mode
      },
      summary: summary,
      location_networks: paginated_data,
      meta: {
        current_page: @page,
        next_page: @page < total_pages(total_count) ? @page + 1 : nil,
        prev_page: @page > 1 ? @page - 1 : nil,
        total_pages: total_pages(total_count),
        total_count: total_count
      }
    }
  rescue StandardError => e
    Rails.logger.error("EndpointLocationStatusService Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    error_response("Internal server error: #{e.message}")
  end

  private

  def fetch_location_metrics(endpoint)
    query = build_location_query

    Rails.logger.info("Executing query: #{query}")
    results = client.select_all(query)

    # Process results and determine status for each location
    locations = []

    results.each do |row|
      next if row["sample_count"].to_i.zero?

      location_network_id = row["location_network_id"]
      avg_latency = calculate_avg_metric(row, "latency") || 0.0

      # Determine status based on endpoint thresholds
      status_info = determine_location_status(row)

      # Get status timeline to determine up_since/down_since
      status_timeline = get_status_timeline(location_network_id, endpoint, status_info[:status])

      location_data = {
        location_network_id: location_network_id,
        region: row["region"],
        isp: row["isp"],
        isp_count: row["isp_count"].to_i,
        region_count: row["region_count"].to_i,
        router_inventory_count: row["router_inventory_count"].to_i,
        device_count: row["device_count"].to_i,
        avg_latency_ms: avg_latency.to_f.round(2),
        sample_count: row["sample_count"].to_i,
        status: status_info[:status]
      }

      # Add up_since or down_since based on status
      if status_info[:status] == "down"
        location_data[:down_since] = status_timeline[:down_since]
      else
        location_data[:up_since] = status_timeline[:up_since]
      end

      locations << location_data
    end

    # Sort by status (down first) and then by avg_latency
    locations.sort_by { |l| [ l[:status] == "down" ? 0 : 1, l[:avg_latency_ms] || 0.0 ] }
  end

  def build_location_query
    if @table_type == :rollup
      <<~SQL
        SELECT
          location_network_id,
          any(region) AS region,
          any(isp) AS isp,
          1 AS isp_count,
          1 AS region_count,
          1 AS router_inventory_count,
          1 AS device_count,
          sum(sum_latency) AS total_latency,
          sum(good_count) AS good_count,
          sum(warning_count) AS warning_count,
          sum(critical_count) AS critical_count,
          sum(down_count) AS down_count,
          sum(samples) AS sample_count
        FROM router_metrics_rollup
        WHERE org_id = '#{@org_id}'
          AND endpoint_id = '#{@endpoint_id}'
          AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.iso8601}')
                    AND parseDateTimeBestEffort('#{@end_time.iso8601}')
        GROUP BY location_network_id
        ORDER BY location_network_id
      SQL
    else
      <<~SQL
        SELECT
          location_network_id,
          any(region) AS region,
          any(isp) AS isp,
          1 AS isp_count,
          1 AS region_count,
          1 AS router_inventory_count,
          1 AS device_count,
          avg(latency_ms) AS avg_latency,
          countIf(status = 1) AS good_count,
          countIf(status = 2) AS warning_count,
          countIf(status = 3) AS critical_count,
          countIf(status = 4) AS down_count,
          count(*) AS sample_count
        FROM router_metrics_raw
        WHERE org_id = '#{@org_id}'
          AND endpoint_id = '#{@endpoint_id}'
          AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.iso8601}')
                    AND parseDateTimeBestEffort('#{@end_time.iso8601}')
        GROUP BY location_network_id
        ORDER BY location_network_id
      SQL
    end
  end

  def get_status_timeline(location_network_id, endpoint, current_status)
    # For now, use the time window bounds as the status change time
    # In a full implementation, this would query historical data to find actual status changes
    status_time = current_status != "down" ? @start_time : @end_time

    {
      up_since: current_status != "down" ? status_time : nil,
      down_since: current_status == "down" ? status_time : nil
    }
  end

  def determine_location_status(row)
    status = determine_status_from_counts(
      row["good_count"].to_i,
      row["warning_count"].to_i,
      row["critical_count"].to_i,
      row["down_count"].to_i
    )

    { status: status }
  end

  def calculate_avg_metric(row, metric_type)
    if @table_type == :rollup
      total = row["total_latency"].to_f
      samples = row["sample_count"].to_f
      samples > 0 ? total / samples : 0.0
    else
      row["avg_latency"].to_f
    end
  end

  def calculate_summary(locations)
    return empty_summary if locations.empty?

    total_locations = locations.size
    good_count = locations.count { |l| l[:status] == "good" }
    warning_count = locations.count { |l| l[:status] == "warning" }
    critical_count = locations.count { |l| l[:status] == "critical" }
    down_count = locations.count { |l| l[:status] == "down" }

    # Aggregate counts
    total_isp = locations.sum { |l| l[:isp_count] }
    total_region = locations.sum { |l| l[:region_count] }
    total_router = locations.sum { |l| l[:router_inventory_count] }
    total_device = locations.sum { |l| l[:device_count] }

    # Calculate weighted averages
    total_samples = locations.sum { |l| l[:sample_count] || 0 }

    avg_latency = if total_samples > 0
      locations.sum { |l| (l[:avg_latency_ms] || 0.0) * (l[:sample_count] || 0) } / total_samples
    else
      0.0
    end

    {
      location_network_count: total_locations,
      good_locations: good_count,
      warning_locations: warning_count,
      critical_locations: critical_count,
      down_locations: down_count,
      good_percentage: (good_count.to_f / total_locations * 100).round(2),
      warning_percentage: (warning_count.to_f / total_locations * 100).round(2),
      critical_percentage: (critical_count.to_f / total_locations * 100).round(2),
      down_percentage: (down_count.to_f / total_locations * 100).round(2),
      isp_count: total_isp,
      region_count: total_region,
      router_inventory_count: total_router,
      device_count: total_device,
      avg_latency_ms: avg_latency.round(2)
    }
  end

  def empty_summary
    {
      location_network_count: 0,
      good_locations: 0,
      warning_locations: 0,
      critical_locations: 0,
      down_locations: 0,
      good_percentage: 0.0,
      warning_percentage: 0.0,
      critical_percentage: 0.0,
      down_percentage: 0.0,
      isp_count: 0,
      region_count: 0,
      router_inventory_count: 0,
      device_count: 0,
      avg_latency_ms: 0.0
    }
  end

  def paginate_results(locations)
    start_index = (@page - 1) * @per_page
    end_index = start_index + @per_page - 1
    locations[start_index..end_index] || []
  end

  def total_pages(total_count)
    (total_count.to_f / @per_page).ceil
  end

  def calculate_duration_hours
    return 0 if @start_time.nil? || @end_time.nil?

    start_t = parse_time_utc(@start_time, Time.current.utc)
    end_t = parse_time_utc(@end_time, Time.current.utc)
    ((end_t - start_t) / 3600.0).round(2)
  end

  def error_response(message)
    {
      error: message,
      time_window: {
        start_time: @start_time,
        end_time: @end_time
      },
      summary: empty_summary,
      location_networks: [],
      meta: {
        current_page: @page,
        next_page: nil,
        prev_page: nil,
        total_pages: 0,
        total_count: 0
      }
    }
  end
end
