# frozen_string_literal: true

# Base class for all ClickHouse models
# Uses clickhouse-activerecord gem for ActiveRecord-style queries
module Clickhouse
  class Base < ActiveRecord::Base
    self.abstract_class = true

    connects_to database: { writing: :clickhouse, reading: :clickhouse }

    # ClickHouse doesn't support primary keys in the traditional sense
    self.primary_key = nil

    # Execute raw SQL and return results
    def self.execute_sql(sql)
      connection.select_all(sql).to_a
    end

    # Execute raw SQL and return first result
    def self.execute_sql_one(sql)
      connection.select_one(sql)
    end

    # Execute raw SQL without expecting results (INSERT, etc.)
    def self.execute_raw(sql)
      connection.execute(sql)
    end
  end
end
