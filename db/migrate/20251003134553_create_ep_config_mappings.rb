class CreateEpConfigMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :ep_config_mappings do |t|
      t.string  :resourceable_type, null: false
      t.bigint  :resourceable_id, null: false
      t.bigint  :endpoint_monitoring_group_id, null: false

      t.timestamps
    end

    add_index :ep_config_mappings, [ :resourceable_type, :resourceable_id ], name: "index_ep_config_mappings_on_resource"
    add_index :ep_config_mappings, :endpoint_monitoring_group_id
  end
end
