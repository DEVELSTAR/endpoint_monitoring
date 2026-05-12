# frozen_string_literal: true

# ActiveRecord model for internet_quality_1h ClickHouse table
# This table stores 1-hour aggregated internet quality metrics
module Clickhouse
  class InternetQuality1h < Base
    self.table_name = "internet_quality_1h"
  end
end
