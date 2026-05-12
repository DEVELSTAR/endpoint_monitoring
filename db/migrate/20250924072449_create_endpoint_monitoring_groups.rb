class CreateEndpointMonitoringGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :endpoint_monitoring_groups do |t|
      t.string :name, null: false
      t.string :group_type
      t.integer :user_id
      t.integer :organisation_id

      t.timestamps
    end

    add_index :endpoint_monitoring_groups, :name
    add_index :endpoint_monitoring_groups, :group_type
  end
end
