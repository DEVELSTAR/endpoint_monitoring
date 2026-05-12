module Api
  module V1
    class HealthController < ApplicationController
      before_action :authenticate_user!
      authorize_resource class: false

      def check
        checks = {
          database_primary: database_primary_check,
          database_legacy: database_legacy_check,
          clickhouse: clickhouse_check,
          redis: redis_check,
          cache: cache_check
        }

        all_healthy = checks.values.all? { |check| check[:status] == "ok" }
        status_code = all_healthy ? :ok : :service_unavailable

        render json: {
          status: all_healthy ? "ok" : "error",
          timestamp: Time.current.iso8601,
          uptime: uptime_seconds,
          checks: checks
        }, status: status_code
      end

      private

      def database_primary_check
        start_time = Time.current
        result = ApplicationRecord.connection.execute("SELECT 1 as test").first
        query_time = ((Time.current - start_time) * 1000).round(2)

        {
          status: "ok",
          message: "Primary database connection successful",
          query_time_ms: query_time,
          adapter: ApplicationRecord.connection.adapter_name,
          database: ApplicationRecord.connection.current_database
        }
      rescue => e
        {
          status: "error",
          message: "Primary database connection failed",
          error: e.message
        }
      end

      def database_legacy_check
        start_time = Time.current
        result = CloudControllerRecord.connection.execute("SELECT 1 as test").first
        query_time = ((Time.current - start_time) * 1000).round(2)

        {
          status: "ok",
          message: "Legacy database connection successful",
          query_time_ms: query_time,
          adapter: CloudControllerRecord.connection.adapter_name,
          database: CloudControllerRecord.connection.current_database
        }
      rescue => e
        {
          status: "error",
          message: "Legacy database connection failed",
          error: e.message
        }
      end

      def clickhouse_check
        start_time = Time.current
        result = Clickhouse::Base.execute_sql_one("SELECT 1 as test")
        query_time = ((Time.current - start_time) * 1000).round(2)
        
        # Get database name from ClickHouse directly
        db_info = Clickhouse::Base.execute_sql_one("SELECT currentDatabase() as database")
        database_name = db_info&.[]('database') || ENV.fetch('CLICKHOUSE_DB', 'default')

        {
          status: "ok",
          message: "ClickHouse connection successful",
          query_time_ms: query_time,
          adapter: "clickhouse-activerecord",
          database: database_name
        }
      rescue => e
        {
          status: "error",
          message: "ClickHouse connection failed",
          error: e.message
        }
      end

      def redis_check
        start_time = Time.current
        test_key = "health_check_#{Time.current.to_i}"
        
        $redis.set(test_key, "ok", ex: 10)
        result = $redis.get(test_key)
        $redis.del(test_key)
        
        response_time = ((Time.current - start_time) * 1000).round(2)

        if result == "ok"
          {
            status: "ok",
            message: "Redis connection successful",
            response_time_ms: response_time,
            redis_url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/12")
          }
        else
          {
            status: "error",
            message: "Redis read/write test failed"
          }
        end
      rescue => e
        {
          status: "error",
          message: "Redis connection failed",
          error: e.message
        }
      end

      def cache_check
        start_time = Time.current
        test_key = "health_cache_#{Time.current.to_i}"
        
        Rails.cache.write(test_key, "ok", expires_in: 10.seconds)
        result = Rails.cache.read(test_key)
        Rails.cache.delete(test_key)
        
        response_time = ((Time.current - start_time) * 1000).round(2)

        if result == "ok"
          {
            status: "ok",
            message: "Rails cache successful",
            response_time_ms: response_time,
            cache_store: Rails.cache.class.name
          }
        else
          {
            status: "error",
            message: "Rails cache read/write test failed"
          }
        end
      rescue => e
        {
          status: "error",
          message: "Rails cache failed",
          error: e.message
        }
      end

      def uptime_seconds
        start_time = Rails.application.config.booted_at || Time.current
        (Time.current - start_time).to_i
      end
    end
  end
end