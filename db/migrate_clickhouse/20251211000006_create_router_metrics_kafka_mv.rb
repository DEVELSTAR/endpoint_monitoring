# frozen_string_literal: true

class CreateRouterMetricsKafkaMv < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS router_metrics_kafka_mv
      TO router_metrics_raw
      AS
      SELECT
        ts,
        org_id,
        endpoint_id,
        host,
        device_id,
        isp,
        region,
        location_network_id,
        router_inventory_id,
        latitude,
        longitude,
        uplink_id,
        uplink_type,
        latency_ms,
        loss_pct,
        http_status,
        tcp_status
      FROM router_metrics_kafka
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS router_metrics_kafka_mv"
  end
end
