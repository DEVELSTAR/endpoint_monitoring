class AddIndexesToEpConfigMappings < ActiveRecord::Migration[8.0]
  def change
    # Add composite index for polymorphic lookups with endpoint_monitoring_group_id
    # This helps when loading ep_config_mappings with their associated resources
    add_index :ep_config_mappings,
              [:resourceable_type, :resourceable_id, :endpoint_monitoring_group_id],
              name: "index_ep_config_on_type_id_and_group",
              if_not_exists: true
  end
end
