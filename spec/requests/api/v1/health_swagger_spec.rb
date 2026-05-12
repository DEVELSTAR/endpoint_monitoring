# spec/requests/api/v1/health_swagger_spec.rb
require 'swagger_helper'

RSpec.describe 'Health API', type: :request do
  path '/api/v1/health' do
    get 'Get application health status' do
      tags 'Health'
      description 'Returns the health status of various services like database, clickhouse, redis, and cache'
      operationId 'getHealth'
      produces 'application/json'

      security [ { api_key: [] } ]

      response '200', 'Successful health check' do
        schema type: :object,
               properties: {
                 status: { type: :string, example: 'ok' },
                 timestamp: { type: :string, format: 'date-time' },
                 uptime: { type: :integer, example: 3600 },
                 checks: {
                   type: :object,
                   properties: {
                     database_primary: {
                       type: :object,
                       properties: {
                         status: { type: :string, example: 'ok' },
                         message: { type: :string, example: 'Primary database connection successful' },
                         query_time_ms: { type: :number, example: 1.5 },
                         adapter: { type: :string, example: 'postgresql' },
                         database: { type: :string, example: 'endpoint_monitoring_development' }
                       }
                     },
                     database_legacy: {
                       type: :object,
                       properties: {
                         status: { type: :string, example: 'ok' },
                         message: { type: :string, example: 'Legacy database connection successful' },
                         query_time_ms: { type: :number, example: 2.1 },
                         adapter: { type: :string, example: 'mysql2' },
                         database: { type: :string, example: 'cloud_controller' }
                       }
                     },
                     clickhouse: {
                       type: :object,
                       properties: {
                         status: { type: :string, example: 'ok' },
                         message: { type: :string, example: 'ClickHouse connection successful' },
                         query_time_ms: { type: :number, example: 10.5 },
                         adapter: { type: :string, example: 'clickhouse-activerecord' },
                         database: { type: :string, example: 'default' }
                       }
                     },
                     redis: {
                       type: :object,
                       properties: {
                         status: { type: :string, example: 'ok' },
                         message: { type: :string, example: 'Redis connection successful' },
                         response_time_ms: { type: :number, example: 0.8 },
                         redis_url: { type: :string, example: 'redis://127.0.0.1:6379/12' }
                       }
                     },
                     cache: {
                       type: :object,
                       properties: {
                         status: { type: :string, example: 'ok' },
                         message: { type: :string, example: 'Rails cache successful' },
                         response_time_ms: { type: :number, example: 0.5 },
                         cache_store: { type: :string, example: 'ActiveSupport::Cache::RedisCacheStore' }
                       }
                     }
                   }
                 }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:admin_user))
          allow_any_instance_of(Api::V1::HealthController).to receive(:authorize!).and_return(true)

          allow(ApplicationRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
          allow(CloudControllerRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
          allow(Clickhouse::Base).to receive(:execute_sql_one).and_return({ "test" => 1 })
          allow($redis).to receive(:set).and_return("OK")
          allow($redis).to receive(:get).and_return("ok")
          allow($redis).to receive(:del).and_return(1)
          allow(Rails.cache).to receive(:write).and_return(true)
          allow(Rails.cache).to receive(:read).and_return("ok")
          allow(Rails.cache).to receive(:delete).and_return(true)
        end

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:'X-AUTH-TOKEN') { 'invalid' }
        run_test!
      end

      response '503', 'Service Unavailable' do
        schema type: :object,
               properties: {
                 status: { type: :string, example: 'error' },
                 timestamp: { type: :string, format: 'date-time' },
                 uptime: { type: :integer, example: 3600 },
                 checks: { type: :object }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:admin_user))
          allow_any_instance_of(Api::V1::HealthController).to receive(:authorize!).and_return(true)

          allow(ApplicationRecord.connection).to receive(:execute).and_raise(StandardError.new("DB connection failed"))
          
          # Other mocks to prevent real calls
          allow(CloudControllerRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
          allow(Clickhouse::Base).to receive(:execute_sql_one).and_return({ "test" => 1 })
          allow($redis).to receive(:set).and_return("OK")
          allow($redis).to receive(:get).and_return("ok")
          allow($redis).to receive(:del).and_return(1)
          allow(Rails.cache).to receive(:write).and_return(true)
          allow(Rails.cache).to receive(:read).and_return("ok")
          allow(Rails.cache).to receive(:delete).and_return(true)
        end

        run_test!
      end
    end
  end
end
