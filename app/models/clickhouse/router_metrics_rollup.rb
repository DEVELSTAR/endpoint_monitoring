# frozen_string_literal: true

# ActiveRecord model for router_metrics_rollup ClickHouse table
module Clickhouse
  class RouterMetricsRollup < Base
    self.table_name = "router_metrics_rollup"
  end
end
