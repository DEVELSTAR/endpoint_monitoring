# frozen_string_literal: true

class CreateRouterMetricsRaw < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS router_metrics_raw (
        ts DateTime('UTC') DEFAULT now(),
        org_id String,
        endpoint_id String,
        host String,
        device_id String,
        isp String,
        region String,
        location_network_id String,
        router_inventory_id String,
        latitude String,
        longitude String,
        uplink_id String,
        uplink_type String,
        latency_ms Int32,
        loss_pct Decimal64(3),
        http_status Int32,
        tcp_status String
      ) ENGINE = MergeTree()
      PARTITION BY toYYYYMM(ts)
      ORDER BY (ts, device_id, host)
      TTL ts + INTERVAL 7 DAY
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS router_metrics_raw"
  end
end
