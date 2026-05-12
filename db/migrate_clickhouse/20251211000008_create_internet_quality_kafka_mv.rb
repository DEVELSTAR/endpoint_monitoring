# frozen_string_literal: true

class CreateInternetQualityKafkaMv < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS internet_quality_kafka_mv
      TO internet_quality_raw
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
      FROM internet_quality_kafka
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS internet_quality_kafka_mv"
  end
end
