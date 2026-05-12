# frozen_string_literal: true

# ActiveRecord model for internet_quality_5m ClickHouse table
# This table stores 5-minute aggregated internet quality metrics
module Clickhouse
  class InternetQuality5m < Base
    self.table_name = "internet_quality_5m"
  end
end
