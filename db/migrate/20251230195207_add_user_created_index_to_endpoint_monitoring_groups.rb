class AddUserCreatedIndexToEndpointMonitoringGroups < ActiveRecord::Migration[8.0]
  def change
    add_index :endpoint_monitoring_groups,
              [:user_id, :created_at],
              name: "index_endpoint_monitoring_groups_on_user_and_created_at"
  end
end