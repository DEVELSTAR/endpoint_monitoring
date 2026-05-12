class AddStatusCountsToRouterMetricsRollup < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      ALTER TABLE router_metrics_rollup
      ADD COLUMN good_count UInt32 DEFAULT 0,
      ADD COLUMN warning_count UInt32 DEFAULT 0,
      ADD COLUMN critical_count UInt32 DEFAULT 0,
      ADD COLUMN down_count UInt32 DEFAULT 0
    SQL

    execute <<~SQL
      ALTER TABLE router_metrics_rollup
      DROP COLUMN count_http_errors,
      DROP COLUMN count_tcp_failures
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE router_metrics_rollup
      DROP COLUMN good_count,
      DROP COLUMN warning_count,
      DROP COLUMN critical_count,
      DROP COLUMN down_count
    SQL

    execute <<~SQL
      ALTER TABLE router_metrics_rollup
      ADD COLUMN count_http_errors UInt64,
      ADD COLUMN count_tcp_failures UInt64
    SQL
  end
end
