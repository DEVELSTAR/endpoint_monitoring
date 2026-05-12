class DashboardResourceService
  def initialize(org_id)
    @org_id = org_id
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      build_payload
    end
  end

  def cache_key
    "dashboard_resource_list/#{org_id}"
  end

  def build_payload
    endpoints = endpoints_relation.pluck(:id, :host)

    {
      mac_ids: mac_ids,
      hosts: endpoints.map { |e| e[1] }.uniq,
      endpoint_ids: endpoints.map { |e| e[0] },
      location_network_ids: location_network_ids,
      router_inventory_ids: router_inventory_ids
    }
  end

  private

  attr_reader :org_id

  def endpoints_relation
    EndpointMonitoringEndpoint
      .joins(:endpoint_monitoring_group)
      .where(endpoint_monitoring_groups: { organisation_id: org_id })
  end

  def mac_ids
    RouterInventory
      .where(organisation_id: org_id)
      .pluck(:mac_id)
      .uniq
  end

  def router_inventory_ids
    RouterInventory
      .where(organisation_id: org_id)
      .pluck(:id)
  end

  def location_network_ids
    LocationNetwork
      .where(organisation_id: org_id)
      .pluck(:id)
  end
end
