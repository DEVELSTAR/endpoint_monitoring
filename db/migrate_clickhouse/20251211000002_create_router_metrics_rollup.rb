# frozen_string_literal: true

class CreateRouterMetricsRollup < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS router_metrics_rollup (
        ts DateTime('UTC') DEFAULT now(),
        org_id String,
        endpoint_id String,
        host String,
        device_id String,
        isp String,
        region String,
        location_network_id String,
        router_inventory_id String,
        uplink_id String,
        uplink_type String,
        sum_latency Float64,
        sum_loss Decimal64(3),
        count_http_errors UInt64,
        count_tcp_failures UInt64,
        samples UInt64
      ) ENGINE = SummingMergeTree()
      PARTITION BY toYYYYMM(ts)
      ORDER BY (
        ts,
        device_id,
        host,
        endpoint_id,
        location_network_id,
        router_inventory_id,
        isp,
        org_id,
        uplink_id,
        uplink_type
      )
      TTL ts + INTERVAL 90 DAY
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS router_metrics_rollup"
  end
end
