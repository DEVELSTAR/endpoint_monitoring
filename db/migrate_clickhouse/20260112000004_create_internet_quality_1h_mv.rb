# frozen_string_literal: true

class CreateInternetQuality1hMv < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS internet_quality_1h_mv
      TO internet_quality_1h
      AS
      SELECT
        toStartOfHour(ts) AS ts,
        org_id,
        device_id,
        uplink_id,
        uplink_type,
        sum(latency_ms) AS sum_latency,
        sum(loss_pct) AS sum_loss,
        count() AS samples
      FROM internet_quality_raw
      GROUP BY
        ts,
        org_id,
        device_id,
        uplink_id,
        uplink_type
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS internet_quality_1h_mv"
  end
end
