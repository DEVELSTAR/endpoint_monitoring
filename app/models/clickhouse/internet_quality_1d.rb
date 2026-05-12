# frozen_string_literal: true

# ActiveRecord model for internet_quality_1d ClickHouse table
# This table stores 1-day aggregated internet quality metrics
module Clickhouse
  class InternetQuality1d < Base
    self.table_name = "internet_quality_1d"
  end
end
