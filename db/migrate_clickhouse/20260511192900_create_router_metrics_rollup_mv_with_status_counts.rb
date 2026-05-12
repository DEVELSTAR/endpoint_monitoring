class CreateRouterMetricsRollupMvWithStatusCounts < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DROP VIEW IF EXISTS router_metrics_rollup_mv
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW router_metrics_rollup_mv
      TO router_metrics_rollup
      AS
      SELECT
        toStartOfInterval(ts, INTERVAL 5 MINUTE) AS ts,
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

        countIf(status = 1) AS good_count,
        countIf(status = 2) AS warning_count,
        countIf(status = 3) AS critical_count,
        countIf(status = 4) AS down_count,
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
    execute <<~SQL
      DROP VIEW IF EXISTS router_metrics_rollup_mv
    SQL
  end
end
