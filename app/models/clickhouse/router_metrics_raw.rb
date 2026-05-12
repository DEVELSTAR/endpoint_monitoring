# frozen_string_literal: true

# ActiveRecord model for router_metrics_raw ClickHouse table
module Clickhouse
  class RouterMetricsRaw < Base
    self.table_name = "router_metrics_raw"
  end
end
