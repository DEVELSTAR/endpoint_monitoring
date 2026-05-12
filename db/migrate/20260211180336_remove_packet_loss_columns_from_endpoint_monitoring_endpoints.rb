class RemovePacketLossColumnsFromEndpointMonitoringEndpoints < ActiveRecord::Migration[8.0]
  def change
    remove_column :endpoint_monitoring_endpoints, :packet_loss_critical, :integer
    remove_column :endpoint_monitoring_endpoints, :packet_loss_warning, :integer
  end
end
