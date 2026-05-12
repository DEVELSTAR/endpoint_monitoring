class EndpointMonitoringGroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :user_id, :organisation_id, :group_type, :associated_resources

  has_many :endpoint_monitoring_endpoints, each_serializer: EndpointMonitoringEndpointSerializer

  def associated_resources
    object.ep_config_mappings.map do |mapping|
      {
        id: mapping.id,
        resourceable_type: mapping.resourceable_type,
        resourceable_id: mapping.resourceable_id,
        endpoint_monitoring_group_id: mapping.endpoint_monitoring_group_id,
        name: fetch_resource_name(mapping)
      }
    end
  end

  private

  def fetch_resource_name(mapping)
    # Use preloaded cache if available (passed from controller)
    if instance_options[:resource_cache]
      cache = instance_options[:resource_cache]
      key = "#{mapping.resourceable_type}:#{mapping.resourceable_id}"
      return cache[key] if cache[key]
    end

    # Fallback to individual queries if cache not available
    case mapping.resourceable_type
    when "RouterInventory"
      RouterInventory.find_by(id: mapping.resourceable_id)&.mac_id || "Unknown Router"
    when "LocationNetwork"
      LocationNetwork.find_by(id: mapping.resourceable_id)&.network_name || "Unknown Network"
    when "ActsAsTaggableOn::Tag"
      Tag.find_by(id: mapping.resourceable_id)&.name || "Unknown Tag"
    else
      "Unknown Resource Type: #{mapping.resourceable_type}"
    end
  end
end
