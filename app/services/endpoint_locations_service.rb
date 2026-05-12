# app/services/endpoint_locations_service.rb
class EndpointLocationsService
  include SqlFilterBuilder
  include ClickhouseClient

  def initialize(org_id: nil, group_by: nil, start_time: nil, end_time: nil, host: nil, endpoint_id: nil,
                 isp: nil, region: nil, location_id: nil, device_id: nil, router_id: nil,
                 sites_type: nil, endpoint: nil)
    @endpoint_id = endpoint_id
    @group_by = validate_group_by(group_by)
    @org_id = org_id
    @host = host
    @device_id = device_id
    @region = region
    @location_id = location_id
    @router_id = router_id
    @isp = isp
    @start_time = start_time
    @end_time = end_time
  end

  def call
    return {} if @org_id.blank?

    data =
      case @group_by
      when "devices"
        fetch_devices_from_clickhouse
      else
        fetch_locations_from_clickhouse
      end

    {
      time_window: {
        start_time: @start_time.iso8601,
        end_time: @end_time.iso8601
      },
      group_by: @group_by,
      data: data
    }
  end

  private

  def fetch_locations_from_clickhouse
    filters = build_sql_filters

    query = <<~SQL
      SELECT groupUniqArray(location_network_id) AS location_ids
      FROM router_metrics_rollup
      WHERE org_id = '#{@org_id}'
        AND location_network_id IS NOT NULL
        AND location_network_id != ''
        AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.utc}')#{' '}
                  AND parseDateTimeBestEffort('#{@end_time.utc}')
        AND samples > 0
        #{"AND #{filters.join(' AND ')}" if filters.any?}
    SQL

    result = client.select_one(query) || {}

    network_ids = result["location_ids"] || []
    return [] if network_ids.empty?

    networks = LocationNetwork
      .where(id: network_ids.map(&:to_i))
      .pluck(:id, :network_name)

    networks.map do |id, name|
      {
        id: id,
        name: name
      }
    end
  end

  def fetch_devices_from_clickhouse
    filters = build_sql_filters

    query = <<~SQL
      SELECT
        router_inventory_id AS id,
        any(device_id) AS mac_id
      FROM router_metrics_rollup
      WHERE org_id = '#{@org_id}'
        AND router_inventory_id IS NOT NULL
        AND router_inventory_id != ''
        AND device_id IS NOT NULL
        AND device_id != ''
        AND ts BETWEEN parseDateTimeBestEffort('#{@start_time.utc}')#{' '}
                  AND parseDateTimeBestEffort('#{@end_time.utc}')
        AND samples > 0
        #{"AND #{filters.join(' AND ')}" if filters.any?}
      GROUP BY router_inventory_id
    SQL

    results = client.select_all(query).to_a

    results.map do |row|
      {
        id: row["id"].to_i,
        mac_id: row["mac_id"]
      }
    end
  end

  def build_sql_filters
    super(
      :org_id,
      :host,
      :region,
      :isp,
      :endpoint_id,
      :location_id,
      :device_id,
      :router_id
    )
  end

  def validate_group_by(group_by)
    valid_options = %w[locations devices]
    valid_options.include?(group_by.to_s) ? group_by.to_s : "locations"
  end
end
