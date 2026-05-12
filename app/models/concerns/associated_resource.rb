module AssociatedResource
  extend ActiveSupport::Concern

  included do
    has_many :ep_config_mappings, dependent: :destroy
    attr_accessor :associated_resources_cache

    after_save :save_associated_resources
  end

  def associated_resources
    @associated_resources_cache ||= ep_config_mappings.map { |c| "#{c.resourceable_type}:#{c.resourceable_id}" }
  end

  def associated_resources=(arr)
    sanitized_values = Array(arr).filter_map do |value|
      next unless value.is_a?(String)

      candidate = value.strip
      next if candidate.blank?

      candidate
    end

    @associated_resources_cache = sanitized_values
  end

  private

  def save_associated_resources
    return unless @associated_resources_cache.present?

    ep_config_mappings.destroy_all
    @associated_resources_cache.each do |v|
      type_prefix, id = v.split(":", 2)
      next unless type_prefix && id

      ep_config_mappings.create!(
        resourceable_type: prefix_mapping(type_prefix),
        resourceable_id: id,
        endpoint_monitoring_group_id: self.id
      )
    end
  end

  def prefix_mapping(prefix)
    { "AP" => "RouterInventory", "network" => "LocationNetwork", "tag" => "ActsAsTaggableOn::Tag" }[prefix] || prefix
  end
end
