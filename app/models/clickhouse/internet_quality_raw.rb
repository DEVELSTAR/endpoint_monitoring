# frozen_string_literal: true

# ActiveRecord model for internet_quality_raw ClickHouse table
module Clickhouse
  class InternetQualityRaw < Base
    self.table_name = "internet_quality_raw"
  end
end
