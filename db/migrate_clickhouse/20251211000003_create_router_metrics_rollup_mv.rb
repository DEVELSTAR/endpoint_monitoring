# frozen_string_literal: true

class CreateRouterMetricsRollupMv < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS router_metrics_rollup_mv
      TO router_metrics_rollup
      AS
      SELECT
        toStartOfHour(ts) AS ts,
        org_id,
        endpoint_id,
        host,
        device_id,
        isp,
        region,
        location_network_id,
        router_inventory_id,
        uplink_id,
        uplink_type,
        sum(latency_ms) AS sum_latency,
        sum(loss_pct) AS sum_loss,
        countIf(http_status >= 500) AS count_http_errors,
        countIf(tcp_status = 'failure') AS count_tcp_failures,
        count() AS samples
      FROM router_metrics_raw
      GROUP BY
        ts,
        device_id,
        host,
        endpoint_id,
        region,
        location_network_id,
        router_inventory_id,
        isp,
        org_id,
        uplink_id,
        uplink_type
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS router_metrics_rollup_mv"
  end
end
