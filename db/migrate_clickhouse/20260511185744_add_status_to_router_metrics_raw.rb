class AddStatusToRouterMetricsRaw < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      ALTER TABLE router_metrics_raw
      ADD COLUMN status UInt8 DEFAULT 1
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE router_metrics_raw
      DROP COLUMN status
    SQL
  end
end
