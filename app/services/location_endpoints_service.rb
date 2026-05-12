# app/services/location_endpoints_service.rb
class LocationEndpointsService
  include ClickhouseClient
  include StatusClassifier
  include UtcTimeParser
  include SqlFilterBuilder

  def initialize(org_id: nil, group_by: nil, start_time: nil, end_time: nil, host: nil, endpoint_id: nil,
                 isp: nil, region: nil, location_id: nil, device_id: nil, router_id: nil, sites_type: nil)
    @org_id = org_id
    @start_time = parse_time_utc(start_time, 24.hours.ago.utc)
    @end_time = parse_time_utc(end_time, Time.current.utc)
    @group_by = validate_group_by(group_by)
    @endpoint_id = endpoint_id
    @host = host
    @device_id = device_id
    @region = region
    @location_id = location_id
    @router_id = router_id
    @isp = isp
  end

  def call
    endpoint_metrics = fetch_from_rollup
    location_counts = classify_and_count_by_group(endpoint_metrics)

    {
      time_window: {
        start_time: @start_time.iso8601,
        end_time: @end_time.iso8601
      },
      group_by: @group_by,
      data: location_counts.values
    }
  end

  private

  def fetch_from_rollup
    group_column = @group_by == "locations" ? "location_network_id" : "region"

    # Build filter conditions
    filter_conditions = build_sql_filters(:endpoint_id, :host, :device_id, :region, :location_id, :router_id, :isp)

    query = <<~SQL
      SELECT
        endpoint_id,
        #{group_column},
        round(sum(sum_latency) / nullIf(sum(samples), 0), 2) AS avg_latency_ms,
        sum(good_count) AS good_count,
        sum(warning_count) AS warning_count,
        sum(critical_count) AS critical_count,
        sum(down_count) AS down_count,
        sum(samples) AS sample_count
      FROM router_metrics_rollup
      WHERE org_id = '#{@org_id}'
        AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.utc}')#{' '}
                  AND parseDateTimeBestEffort('#{@end_time.utc}')
        AND samples > 0
        #{"AND #{filter_conditions.join(' AND ')}" if filter_conditions.any?}
      GROUP BY endpoint_id, #{group_column}
    SQL

    client.select_all(query).to_a
  end

  def classify_and_count_by_group(endpoint_metrics)
    group_column = @group_by == "locations" ? "location_network_id" : "region"
    key_name = @group_by == "locations" ? :location : :region

    location_data = Hash.new do |h, key|
      h[key] = {
        key_name => key,
        count: 0,
        good: 0,
        warning: 0,
        critical: 0,
        down: 0
      }
    end

    endpoint_metrics.each do |row|
      key = row[group_column]
      next if key.blank?

      status = determine_status_from_counts(
        row["good_count"].to_i,
        row["warning_count"].to_i,
        row["critical_count"].to_i,
        row["down_count"].to_i
      ).to_sym

      location_data[key][:count] += 1
      location_data[key][status] += 1
    end

    add_location_names(location_data) if @group_by == "locations"

    location_data
  end

  def add_location_names(location_data)
    location_ids = location_data.keys.map(&:to_i)
    return if location_ids.empty?

    networks = LocationNetwork.where(id: location_ids.map(&:to_i))
    networks = networks.pluck(:id, :network_name)
    networks_hash = {}
    networks.each { |id, name| networks_hash[id] = { network_name: name } }
    networks = networks_hash

    location_data.each do |id, data|
      network = networks[id.to_i]
      data[:name] = network[:network_name] if network.is_a?(Hash)
    end
  end

  def validate_group_by(group_by)
    valid_options = %w[regions locations]
    valid_options.include?(group_by.to_s) ? group_by.to_s : "regions"
  end
end
