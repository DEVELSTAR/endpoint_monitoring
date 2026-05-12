class CreateEndpointMonitoringEndpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :endpoint_monitoring_endpoints do |t|
      t.references :endpoint_monitoring_group, null: false, foreign_key: true
      t.string :name, null: false
      t.string :host, null: false
      t.string :monitoring_mode, null: false
      t.integer :port
      t.integer :latency_critical
      t.integer :packet_loss_critical
      t.integer :latency_warning
      t.integer :packet_loss_warning
      t.integer :response_time
      t.json :acceptable_response_codes

      t.timestamps
    end

    add_index :endpoint_monitoring_endpoints, :host
    add_index :endpoint_monitoring_endpoints, :name
    add_index :endpoint_monitoring_endpoints, :monitoring_mode
  end
end
