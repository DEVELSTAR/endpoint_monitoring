# frozen_string_literal: true

class CreateInternetQuality5m < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS internet_quality_5m (
        ts DateTime('UTC'),
        org_id String,
        device_id String,
        uplink_id String,
        uplink_type String,
        sum_latency Float64,
        sum_loss Decimal64(3),
        samples UInt64
      ) ENGINE = SummingMergeTree()
      PARTITION BY toYYYYMM(ts)
      ORDER BY (ts, org_id, device_id, uplink_id, uplink_type)
      TTL ts + INTERVAL 7 DAY
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS internet_quality_5m"
  end
end
