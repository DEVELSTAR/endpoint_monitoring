# spec/requests/api/v1/dashboard_swagger_spec.rb
require 'swagger_helper'

RSpec.describe 'Dashboard API', type: :request do
  path '/api/v1/dashboard/latency_analysis' do
    get 'Get latency analysis data' do
      tags 'Dashboard'
      description 'Returns latency analysis data with response efficiency percentages and grouped data'
      operationId 'getLatencyAnalysis'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :group_by, in: :query, type: :string, required: false,
                description: 'Group data by specified field',
                enum: [ 'endpoint_id', 'host', 'device_id', 'region', 'location_id', 'router_id', 'isp', 'isp_region' ],
                default: 'endpoint_id'

      parameter name: :last_minutes, in: :query, type: :integer, required: false,
                description: 'Time window in minutes from now',
                default: 1440

      parameter name: :start_time, in: :query, type: :string, required: false,
                description: 'Start time for analysis (ISO 8601 format)'

      parameter name: :end_time, in: :query, type: :string, required: false,
                description: 'End time for analysis (ISO 8601 format)'

      parameter name: :host, in: :query, type: :string, required: false,
                description: 'Filter by hostname'

      parameter name: :endpoint_id, in: :query, type: :integer, required: false,
                description: 'Filter by specific endpoint ID'

      parameter name: :isp, in: :query, type: :string, required: false,
                description: 'Filter by ISP'

      parameter name: :region, in: :query, type: :string, required: false,
                description: 'Filter by region'

      parameter name: :location_id, in: :query, type: :string, required: false,
                description: 'Filter by location network ID'

      parameter name: :device_id, in: :query, type: :string, required: false,
                description: 'Filter by device MAC address'

      parameter name: :router_id, in: :query, type: :string, required: false,
                description: 'Filter by router inventory ID'

      parameter name: :sites_type, in: :query, type: :string, required: false,
                description: 'Filter by site performance type',
                enum: [ 'good', 'warning', 'critical', 'down' ]

      response '200', 'Successful latency analysis' do
        schema type: :object,
               properties: {
                 time_window: {
                   type: :object,
                   properties: {
                     start_time: { type: :string, format: 'date-time' },
                     end_time: { type: :string, format: 'date-time' }
                   }
                 },
                 group_by: { type: :string },
                 response_efficiency: {
                   type: :object,
                   properties: {
                     good: { type: :number },
                     warning: { type: :number },
                     critical: { type: :number },
                     down: { type: :number },
                     total_count: { type: :integer }
                   }
                 },
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       endpoint_id: { type: :integer },
                       host: { type: :string },
                       device_id: { type: :string },
                       region: { type: :string },
                       location_id: { type: :string },
                       router_id: { type: :string },
                       isp: { type: :string },
                       status: { type: :string, enum: [ 'good', 'warning', 'critical', 'down' ] },
                       group: { type: :string, nullable: true },
                       type: { type: :string, nullable: true },
                       regions: { type: :array, items: { type: :string }, description: 'Array of unique regions where this endpoint has monitoring data (only when group_by=endpoint_id)' },
                       avg_latency_ms: { type: :number },
                       sample_count: { type: :integer },
                       endpoint_count: { type: :integer },
                       device_count: { type: :integer },
                       location_count: { type: :integer }
                     }
                   }
                 }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          # Mock authentication
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          # Mock service response
          mock_response = {
            time_window: {
              start_time: '2024-11-01T00:00:00Z',
              end_time: '2024-11-06T23:59:59Z'
            },
            group_by: 'endpoint_id',
            response_efficiency: {
              good: 65.5,
              warning: 25.0,
              critical: 9.5,
              down: 0.0,
              total_count: 100
            },
            data: [
              {
                endpoint_id: 123,
                status: 'good',
                group: 'Entertainment',
                type: 'icmp',
                regions: [ 'delhi', 'mumbai', 'bangalore' ],
                avg_latency_ms: 45.2,
                sample_count: 1500,
                endpoint_count: 1,
                device_count: 3,
                location_count: 2
              }
            ]
          }

          allow_any_instance_of(LatencyAnalysisService).to receive(:call).and_return(mock_response)
        end

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/site_distribution' do
    get 'Get site distribution data' do
      tags 'Dashboard'
      description 'Returns site distribution analysis with majority vote classification and latency bucket distribution'
      operationId 'getSiteDistribution'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :group_by, in: :query, type: :string, required: false,
                description: 'Group data by specified field',
                enum: [ 'endpoint_id', 'host', 'device_id', 'region', 'location_id', 'router_id', 'isp', 'isp_region' ],
                default: 'endpoint_id'

      parameter name: :bucket_size, in: :query, type: :integer, required: false,
                description: 'Latency bucket size in milliseconds for distribution',
                default: 20

      parameter name: :last_minutes, in: :query, type: :integer, required: false,
                description: 'Time window in minutes from now',
                default: 1440

      parameter name: :start_time, in: :query, type: :string, required: false,
                description: 'Start time for analysis (ISO 8601 format)'

      parameter name: :end_time, in: :query, type: :string, required: false,
                description: 'End time for analysis (ISO 8601 format)'

      parameter name: :host, in: :query, type: :string, required: false,
                description: 'Filter by hostname'

      parameter name: :endpoint_id, in: :query, type: :integer, required: false,
                description: 'Filter by specific endpoint ID'

      parameter name: :isp, in: :query, type: :string, required: false,
                description: 'Filter by ISP'

      parameter name: :region, in: :query, type: :string, required: false,
                description: 'Filter by region'

      parameter name: :location_id, in: :query, type: :string, required: false,
                description: 'Filter by location network ID'

      parameter name: :device_id, in: :query, type: :string, required: false,
                description: 'Filter by device MAC address'

      parameter name: :router_id, in: :query, type: :string, required: false,
                description: 'Filter by router inventory ID'

      parameter name: :sites_type, in: :query, type: :string, required: false,
                description: 'Filter by site performance type',
                enum: [ 'good', 'warning', 'critical', 'down' ]

      response '200', 'Successful site distribution analysis' do
        schema type: :object,
               properties: {
                 time_window: {
                   type: :object,
                   properties: {
                     start_time: { type: :string, format: 'date-time' },
                     end_time: { type: :string, format: 'date-time' }
                   }
                 },
                 group_by: { type: :string },
                 bucket_size: { type: :integer, description: 'Latency bucket size in milliseconds' },
                 summary: {
                   type: :object,
                   properties: {
                     count: { type: :integer, description: 'Total number of groups' },
                     good: { type: :integer, description: 'Number of good groups' },
                     warning: { type: :integer, description: 'Number of warning groups' },
                     critical: { type: :integer, description: 'Number of critical groups' },
                     down: { type: :integer, description: 'Number of down groups' }
                   }
                 },
                 distribution: {
                   type: :array,
                   description: 'Distribution of groups across latency buckets',
                   items: {
                     type: :object,
                     properties: {
                       latency_range: { type: :string, description: 'Latency range (e.g., "0-19ms")' },
                       latency_bucket: { type: :integer, description: 'Bucket start value in ms' },
                       count: { type: :integer, description: 'Number of groups in this bucket' }
                     }
                   }
                 }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          # Mock authentication
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          # Mock service response
          mock_response = {
            time_window: {
              start_time: '2024-11-01T00:00:00Z',
              end_time: '2024-11-06T23:59:59Z'
            },
            group_by: 'endpoint_id',
            bucket_size: 20,
            summary: {
              count: 5,
              good: 3,
              warning: 1,
              critical: 1,
              down: 0
            },
            distribution: [
              {
                latency_range: '0-19ms',
                latency_bucket: 0,
                count: 2
              },
              {
                latency_range: '20-39ms',
                latency_bucket: 20,
                count: 2
              },
              {
                latency_range: '40-59ms',
                latency_bucket: 40,
                count: 1
              }
            ]
          }

          allow_any_instance_of(SiteDistributionService).to receive(:call).and_return(mock_response)
        end

        run_test!
      end

      response '500', 'Internal server error' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          # Mock service error
          allow_any_instance_of(SiteDistributionService).to receive(:call).and_raise(
            StandardError.new('Database connection failed')
          )
        end

        run_test! do |response|
          expect(response.status).to eq(500)
          data = JSON.parse(response.body)
          expect(data).to have_key('error')
        end
      end
    end
  end

  path '/api/v1/dashboard/uplink_timeseries' do
    get 'Get uplink timeseries data' do
      tags 'Dashboard'
      description 'Returns device-level uplink performance timeseries with latency and packet loss metrics grouped by uplink'
      operationId 'getUplinkTimeseries'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :device_id, in: :query, type: :string, required: true,
                description: 'Device MAC address identifier',
                example: '00:11:22:33:44:55'

      parameter name: :uplink_id, in: :query, type: :string, required: false,
                description: 'Filter by specific uplink identifier',
                example: 'uplink-001'

      parameter name: :uplink_type, in: :query, type: :string, required: false,
                description: 'Filter by uplink type',
                enum: [ 'primary', 'secondary' ],
                example: 'primary'

      parameter name: :bucket_minutes, in: :query, type: :integer, required: false,
                description: 'Time bucket size in minutes for data aggregation (default 1)',
                default: 1,
                example: 5

      parameter name: :start_time, in: :query, type: :string, required: false,
                description: 'Start time for analysis (ISO 8601 format)',
                example: '2025-01-01T00:00:00Z'

      parameter name: :end_time, in: :query, type: :string, required: false,
                description: 'End time for analysis (ISO 8601 format)',
                example: '2025-01-01T23:59:59Z'

      parameter name: :last_minutes, in: :query, type: :integer, required: false,
                description: 'Time window in minutes from now (alternative to start_time/end_time)',
                default: 1440,
                example: 60

      response '200', 'Successful uplink timeseries analysis' do
        schema type: :object,
               properties: {
                 time_window: {
                   type: :object,
                   description: 'Time window for the analysis',
                   properties: {
                     start_time: { type: :string, format: 'date-time', example: '2025-01-01T00:00:00Z' },
                     end_time: { type: :string, format: 'date-time', example: '2025-01-01T23:59:59Z' },
                     bucket_minutes: { type: :integer, description: 'Bucket size in minutes', example: 5 }
                   }
                 },
                 latency: {
                   type: :array,
                   description: 'Latency timeseries data grouped by uplink',
                   items: {
                     type: :object,
                     properties: {
                       uplink_id: { type: :string, description: 'Uplink identifier', example: 'uplink-001' },
                       uplink_type: { type: :string, description: 'Type of uplink (primary/secondary)', example: 'primary' },
                       timeseries: {
                         type: :array,
                         description: 'Latency data points over time',
                         items: {
                           type: :object,
                           properties: {
                             timestamp: { type: :string, format: 'date-time', description: 'Timestamp of the data point', example: '2025-01-01T12:00:00Z' },
                             epoch_ts: { type: :integer, description: 'Unix epoch timestamp in seconds', example: 1735732800 },
                             time_ago: { type: :string, description: 'Human-readable time difference from now', example: '2h ago' },
                             avg_latency_ms: { type: :number, description: 'Average latency in milliseconds', example: 25.5 },
                             sample_count: { type: :integer, description: 'Number of samples in this time bucket', example: 100 }
                           }
                         }
                       }
                     }
                   }
                 },
                 loss: {
                   type: :array,
                   description: 'Packet loss timeseries data grouped by uplink',
                   items: {
                     type: :object,
                     properties: {
                       uplink_id: { type: :string, description: 'Uplink identifier', example: 'uplink-001' },
                       uplink_type: { type: :string, description: 'Type of uplink (primary/secondary)', example: 'primary' },
                       timeseries: {
                         type: :array,
                         description: 'Packet loss data points over time',
                         items: {
                           type: :object,
                           properties: {
                             timestamp: { type: :string, format: 'date-time', description: 'Timestamp of the data point', example: '2025-01-01T12:00:00Z' },
                             epoch_ts: { type: :integer, description: 'Unix epoch timestamp in seconds', example: 1735732800 },
                             time_ago: { type: :string, description: 'Human-readable time difference from now', example: '2h ago' },
                             avg_loss_pct: { type: :number, description: 'Average packet loss percentage', example: 1.2 },
                             sample_count: { type: :integer, description: 'Number of samples in this time bucket', example: 100 }
                           }
                         }
                       }
                     }
                   }
                 }
               }

        let(:device_id) { '00:11:22:33:44:55' }
        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          # Mock authentication
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          # Mock service response
          mock_response = {
            time_window: {
              start_time: '2025-01-01T00:00:00Z',
              end_time: '2025-01-01T23:59:59Z',
              bucket_minutes: 5
            },
            latency: [
              {
                uplink_id: 'uplink-001',
                uplink_type: 'primary',
                timeseries: [
                  {
                    timestamp: '2025-01-01T12:00:00Z',
                    epoch_ts: 1735732800,
                    time_ago: '2h ago',
                    avg_latency_ms: 25.5,
                    sample_count: 100
                  },
                  {
                    timestamp: '2025-01-01T12:05:00Z',
                    epoch_ts: 1735733100,
                    time_ago: '2h 25m ago',
                    avg_latency_ms: 28.3,
                    sample_count: 98
                  }
                ]
              },
              {
                uplink_id: 'uplink-002',
                uplink_type: 'secondary',
                timeseries: [
                  {
                    timestamp: '2025-01-01T12:00:00Z',
                    epoch_ts: 1735732800,
                    time_ago: '2h ago',
                    avg_latency_ms: 32.1,
                    sample_count: 95
                  }
                ]
              }
            ],
            loss: [
              {
                uplink_id: 'uplink-001',
                uplink_type: 'primary',
                timeseries: [
                  {
                    timestamp: '2025-01-01T12:00:00Z',
                    epoch_ts: 1735732800,
                    time_ago: '2h ago',
                    avg_loss_pct: 1.2,
                    sample_count: 100
                  },
                  {
                    timestamp: '2025-01-01T12:05:00Z',
                    epoch_ts: 1735733100,
                    time_ago: '2h 25m ago',
                    avg_loss_pct: 0.8,
                    sample_count: 98
                  }
                ]
              },
              {
                uplink_id: 'uplink-002',
                uplink_type: 'secondary',
                timeseries: [
                  {
                    timestamp: '2025-01-01T12:00:00Z',
                    epoch_ts: 1735732800,
                    time_ago: '2h ago',
                    avg_loss_pct: 2.5,
                    sample_count: 95
                  }
                ]
              }
            ]
          }

          allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(mock_response)
        end

        run_test! do |response|
          expect(response.status).to eq(200)
          data = JSON.parse(response.body)
          expect(data).to have_key('time_window')
          expect(data).to have_key('latency')
          expect(data).to have_key('loss')
          expect(data['latency']).to be_an(Array)
          expect(data['loss']).to be_an(Array)
        end
      end

      response '400', 'Bad Request - Missing device_id' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'device_id is required' }
               }

        let(:device_id) { nil }
        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )
        end

        run_test! do |response|
          expect(response.status).to eq(400)
          data = JSON.parse(response.body)
          expect(data['error']).to eq('device_id is required')
        end
      end

      response '401', 'Unauthorized - Invalid or missing authentication token' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Invalid authentication token' }
               }

        let(:device_id) { '00:11:22:33:44:55' }
        let(:'X-AUTH-TOKEN') { 'invalid_token' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!) do |controller|
            controller.render json: { error: 'Invalid authentication token' }, status: :unauthorized
          end
        end

        run_test! do |response|
          expect(response.status).to eq(401)
        end
      end

      response '500', 'Internal server error' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'An error occurred while processing the request' }
               }

        let(:device_id) { '00:11:22:33:44:55' }
        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          # Mock service error
          allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_raise(
            StandardError.new('Database connection failed')
          )
        end

        run_test! do |response|
          expect(response.status).to eq(500)
          data = JSON.parse(response.body)
          expect(data).to have_key('error')
        end
      end
    end
  end

  path '/api/v1/dashboard/endpoint_timeseries' do
    get 'Get full timeseries for a single endpoint' do
      tags 'Dashboard'
      description 'Returns 24-hour buckted timeseries performance data for a single endpoint'
      operationId 'getEndpointTimeseries'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :endpoint_id, in: :query, type: :integer, required: true,
                description: 'Endpoint ID for which to fetch the timeseries'

      parameter name: :date, in: :query, type: :string, required: false, format: :date,
                description: 'Filter by specific date (YYYY-MM-DD format). Returns data for the full day.'

      parameter name: :bucket_minutes, in: :query, type: :integer, required: false,
                description: 'Time bucket size in minutes for data aggregation (default 15)'

      parameter name: :start_time, in: :query, type: :string, required: false,
                description: 'Start time for analysis (ISO 8601 format). Use date parameter for single day queries.'

      parameter name: :end_time, in: :query, type: :string, required: false,
                description: 'End time for analysis (ISO 8601 format). Use date parameter for single day queries.'

      parameter name: :host, in: :query, type: :string, required: false,
                description: 'Filter by hostname'

      parameter name: :isp, in: :query, type: :string, required: false,
                description: 'Filter by ISP'

      parameter name: :region, in: :query, type: :string, required: false,
                description: 'Filter by region'

      parameter name: :location_id, in: :query, type: :string, required: false,
                description: 'Filter by location network ID'

      parameter name: :device_id, in: :query, type: :string, required: false,
                description: 'Filter by device MAC address'

      parameter name: :router_id, in: :query, type: :string, required: false,
                description: 'Filter by router inventory ID'

      response '200', 'Successful endpoint timeseries data retrieval' do
        schema type: :object,
               properties: {
                 time_window: {
                   type: :object,
                   properties: {
                     start_time: { type: :string, format: 'date-time' },
                     end_time: { type: :string, format: 'date-time' }
                   }
                 },
                 response_efficiency: {
                   type: :object,
                   properties: {
                     good: { type: :number },
                     warning: { type: :number },
                     critical: { type: :number },
                     down: { type: :number },
                     total_count: { type: :number }
                   }
                 },
                 endpoint: {
                   type: :object,
                   properties: {
                     endpoint_id: { type: :string },
                     host: { type: :string },
                     group_name: { type: :string },
                     type: { type: :string }
                   }
                 },
                 timeseries: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       timestamp: { type: :string, format: 'date-time' },
                       time_ago: { type: :string },
                       response_time: { type: :number, nullable: true },
                       status: { type: :string }
                     }
                   }
                 },
                 devices_details: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       router_inventory_id: { type: :string },
                       mac_address: { type: :string },
                       timestamp: { type: :string, format: 'date-time' },
                       time_ago: { type: :string },
                       response_time: { type: :number, nullable: true },
                       status: { type: :string }
                     }
                   }
                 }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }
        let(:endpoint_id) { 1 }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 3)
          )

          mock_response = {
            time_window: {
              start_time: '2026-04-14T10:39:32.448Z',
              end_time: '2026-04-15T10:39:32.448Z'
            },
            response_efficiency: {
              good: 0,
              warning: 0,
              critical: 0,
              down: 0,
              total_count: 0
            },
            endpoint: {
              endpoint_id: "1",
              host: "google.com",
              group_name: "Group A",
              type: "HTTP"
            },
            timeseries: [
              {
                timestamp: '2026-04-14T10:39:32.448Z',
                time_ago: '2 hours ago',
                response_time: 100,
                status: 'good'
              }
            ],
            devices_details: [
              {
                router_inventory_id: "1",
                mac_address: "00:11:22:33:44:55",
                timestamp: '2026-04-14T10:39:32.448Z',
                time_ago: '2 hours ago',
                response_time: 100,
                status: 'good'
              }
            ]
          }

          allow_any_instance_of(EndpointTimeseriesService).to receive(:call).and_return(mock_response)
        end

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/endpoint_reports' do
    get 'Get time-bucketed endpoint status percentages' do
      tags 'Dashboard'
      description 'Returns dynamic time-bucketed performance data containing good, critical, and down status percentages'
      operationId 'getEndpointReports'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :group_by, in: :query, type: :string, required: false,
                description: 'Group data by specified field',
                enum: [ 'endpoint_id', 'host', 'device_id', 'region', 'location_id', 'router_id', 'isp', 'isp_region' ],
                default: 'endpoint_id'

      parameter name: :last_minutes, in: :query, type: :integer, required: false,
                description: 'Time window in minutes from now'

      parameter name: :start_time, in: :query, type: :string, required: false,
                description: 'Start time for analysis (ISO 8601 format)'

      parameter name: :end_time, in: :query, type: :string, required: false,
                description: 'End time for analysis (ISO 8601 format)'

      parameter name: :host, in: :query, type: :string, required: false,
                description: 'Filter by hostname'

      parameter name: :endpoint_id, in: :query, type: :integer, required: false,
                description: 'Filter by specific endpoint ID'

      parameter name: :isp, in: :query, type: :string, required: false,
                description: 'Filter by ISP'

      parameter name: :region, in: :query, type: :string, required: false,
                description: 'Filter by region'

      parameter name: :location_id, in: :query, type: :string, required: false,
                description: 'Filter by location network ID'

      parameter name: :device_id, in: :query, type: :string, required: false,
                description: 'Filter by device MAC address'

      parameter name: :router_id, in: :query, type: :string, required: false,
                description: 'Filter by router inventory ID'

      response '200', 'Successful endpoint reports data retrieval' do
        schema type: :object,
               properties: {
                 time_window: {
                   type: :object,
                   properties: {
                     start_time: { type: :string, format: 'date-time' },
                     end_time: { type: :string, format: 'date-time' }
                   }
                 },
                 group_by: { type: :string },
                 summary: {
                   type: :object,
                   properties: {
                     good: { type: :number },
                     critical: { type: :number },
                     down: { type: :number }
                   }
                 },
                 metrics: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       time: { type: :string, format: 'date-time' },
                       good: { type: :number },
                       critical: { type: :number },
                       down: { type: :number }
                     }
                   }
                 }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          mock_response = {
            time_window: {
              start_time: '2024-11-01T00:00:00Z',
              end_time: '2024-11-06T23:59:59Z'
            },
            group_by: 'endpoint_id',
            summary: {
              good: 100.0,
              critical: 0.0,
              down: 0.0
            },
            metrics: [
              {
                time: '2024-11-01T00:00:00Z',
                good: 100.0,
                critical: 0.0,
                down: 0.0
              }
            ]
          }

          allow_any_instance_of(EndpointReportsService).to receive(:call).and_return(mock_response)
        end

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/resource_list' do
    get 'Get dashboard filter dropdown values' do
      tags 'Dashboard'
      description 'Returns distinct values for all filterable fields to populate dashboard filter dropdowns. Supports cascading filters.'
      operationId 'getResourceList'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :device_id, in: :query, type: :string, required: false,
                description: 'Filter by device ID to narrow down other field options'

      parameter name: :host, in: :query, type: :string, required: false,
                description: 'Filter by hostname to narrow down other field options'

      parameter name: :endpoint_id, in: :query, type: :string, required: false,
                description: 'Filter by endpoint ID to narrow down other field options'

      parameter name: :region, in: :query, type: :string, required: false,
                description: 'Filter by region to narrow down other field options'

      parameter name: :location_network_id, in: :query, type: :string, required: false,
                description: 'Filter by location network ID to narrow down other field options'

      parameter name: :router_inventory_id, in: :query, type: :string, required: false,
                description: 'Filter by router inventory ID to narrow down other field options'

      parameter name: :isp, in: :query, type: :string, required: false,
                description: 'Filter by ISP to narrow down other field options'

      response '200', 'Successful resource list retrieval' do
        schema type: :object,
               properties: {
                 mac_ids: {
                   type: :array,
                   items: { type: :string },
                   description: 'List of unique device IDs'
                 },
                 hosts: {
                   type: :array,
                   items: { type: :string },
                   description: 'List of unique hostnames'
                 },
                 endpoint_ids: {
                   type: :array,
                   items: { type: :string },
                   description: 'List of unique endpoint IDs'
                 },
                 regions: {
                   type: :array,
                   items: { type: :string },
                   description: 'List of unique regions'
                 },
                 location_network_ids: {
                   type: :array,
                   items: { type: :string },
                   description: 'List of unique location network IDs'
                 },
                 router_inventory_ids: {
                   type: :array,
                   items: { type: :string },
                   description: 'List of unique router inventory IDs'
                 },
                 isps: {
                   type: :array,
                   items: { type: :string },
                   description: 'List of unique ISPs'
                 }
               },
               required: [ 'mac_ids', 'hosts', 'endpoint_ids', 'regions', 'location_network_ids', 'router_inventory_ids', 'isps' ]

        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          allow_any_instance_of(Api::V1::DashboardController).to receive(:authenticate_user!)
          allow_any_instance_of(Api::V1::DashboardController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          mock_ch_result = {
            'regions' => [ 'Delhi', 'Mumbai' ],
            'isps' => [ 'Airtel', 'Jio' ]
          }
          mock_db_result = {
            mac_ids: [ 'device1', 'device2' ],
            hosts: [ 'google.com', 'amazon.com' ],
            endpoint_ids: [ '1', '2' ],
            location_network_ids: [ 'loc1', 'loc2' ],
            router_inventory_ids: [ 'router1', 'router2' ]
          }

          allow(Clickhouse::Base).to receive(:connection).and_return(double('connection'))
          allow(Clickhouse::Base.connection).to receive(:select_one).and_return(mock_ch_result)

          mock_service = instance_double(DashboardResourceService)
          allow(DashboardResourceService).to receive(:new).with(6).and_return(mock_service)
          allow(mock_service).to receive(:call).and_return(mock_db_result)
        end

        run_test! do |response|
          expect(response.status).to eq(200)
          data = JSON.parse(response.body)

          expect(data).to have_key('mac_ids')
          expect(data).to have_key('hosts')
          expect(data).to have_key('endpoint_ids')
          expect(data).to have_key('regions')
          expect(data).to have_key('location_network_ids')
          expect(data).to have_key('router_inventory_ids')
          expect(data).to have_key('isps')

          expect(data['mac_ids']).to be_an(Array)
          expect(data['hosts']).to be_an(Array)
          expect(data['endpoint_ids']).to be_an(Array)
          expect(data['regions']).to be_an(Array)
          expect(data['location_network_ids']).to be_an(Array)
          expect(data['router_inventory_ids']).to be_an(Array)
          expect(data['isps']).to be_an(Array)
        end
      end

      response '200', 'Resource list with applied filters' do
        schema type: :object,
               properties: {
                 mac_ids: { type: :array, items: { type: :string } },
                 hosts: { type: :array, items: { type: :string } },
                 endpoint_ids: { type: :array, items: { type: :string } },
                 regions: { type: :array, items: { type: :string } },
                 location_network_ids: { type: :array, items: { type: :string } },
                 router_inventory_ids: { type: :array, items: { type: :string } },
                 isps: { type: :array, items: { type: :string } }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }
        let(:region) { 'Delhi' }
        let(:isp) { 'Airtel' }

        before do
          allow_any_instance_of(Api::V1::DashboardController).to receive(:authenticate_user!)
          allow_any_instance_of(Api::V1::DashboardController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          filtered_ch_result = {
            'regions' => [ 'Delhi' ],
            'isps' => [ 'Airtel' ]
          }
          mock_db_result = {
            mac_ids: [ 'device1' ],
            hosts: [ 'google.com' ],
            endpoint_ids: [ '1' ],
            location_network_ids: [ 'loc1' ],
            router_inventory_ids: [ 'router1' ]
          }

          allow(Clickhouse::Base).to receive(:connection).and_return(double('connection'))
          allow(Clickhouse::Base.connection).to receive(:select_one).and_return(filtered_ch_result)

          mock_service = instance_double(DashboardResourceService)
          allow(DashboardResourceService).to receive(:new).with(6).and_return(mock_service)
          allow(mock_service).to receive(:call).and_return(mock_db_result)
        end

        run_test! do |response|
          expect(response.status).to eq(200)
          data = JSON.parse(response.body)

          expect(data['regions']).to include('Delhi')
          expect(data['isps']).to include('Airtel')
        end
      end

      response '200', 'Empty resource list when no data matches filters' do
        schema type: :object,
               properties: {
                 mac_ids: { type: :array, items: { type: :string } },
                 hosts: { type: :array, items: { type: :string } },
                 endpoint_ids: { type: :array, items: { type: :string } },
                 regions: { type: :array, items: { type: :string } },
                 location_network_ids: { type: :array, items: { type: :string } },
                 router_inventory_ids: { type: :array, items: { type: :string } },
                 isps: { type: :array, items: { type: :string } }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          allow_any_instance_of(Api::V1::DashboardController).to receive(:authenticate_user!)
          allow_any_instance_of(Api::V1::DashboardController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          allow(Clickhouse::Base).to receive(:connection).and_return(double('connection'))
          allow(Clickhouse::Base.connection).to receive(:select_one).and_return(nil)

          mock_service = instance_double(DashboardResourceService)
          allow(DashboardResourceService).to receive(:new).with(6).and_return(mock_service)
          allow(mock_service).to receive(:call).and_return({})
        end

        run_test! do |response|
          expect(response.status).to eq(200)
          data = JSON.parse(response.body)

          expect(data['mac_ids']).to eq([])
          expect(data['hosts']).to eq([])
          expect(data['endpoint_ids']).to eq([])
          expect(data['regions']).to eq([])
          expect(data['location_network_ids']).to eq([])
          expect(data['router_inventory_ids']).to eq([])
          expect(data['isps']).to eq([])
        end
      end

      response '401', 'Unauthorized - Invalid or missing authentication token' do
        let(:'X-AUTH-TOKEN') { 'invalid_token' }

        before do
          allow(User).to receive(:find_by).with(access_token: 'invalid_token').and_return(nil)
        end

        run_test!
      end

      response '400', 'Bad Request - Missing organisation_id' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          allow_any_instance_of(Api::V1::DashboardController).to receive(:authenticate_user!)
          allow_any_instance_of(Api::V1::DashboardController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: nil)
          )
        end

        run_test! do |response|
          expect(response.status).to eq(400)
          data = JSON.parse(response.body)
          expect(data).to have_key('error')
        end
      end

      response '500', 'Internal Server Error - ClickHouse query failure' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }

        before do
          allow_any_instance_of(Api::V1::DashboardController).to receive(:authenticate_user!)
          allow_any_instance_of(Api::V1::DashboardController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 6)
          )

          allow(Clickhouse::Base).to receive(:connection).and_return(double('connection'))
          allow(Clickhouse::Base.connection).to receive(:select_one)
            .and_raise(StandardError.new('ClickHouse error'))
          allow(Rails.logger).to receive(:error)
        end

        run_test! do |response|
          expect(response.status).to eq(500)
          data = JSON.parse(response.body)
          expect(data).to have_key('error')
        end
      end
    end
  end

  path '/api/v1/dashboard/location_endpoints' do
    get 'Get location-wise endpoint counts' do
      tags 'Dashboard'
      description 'Returns endpoint counts (total/good/warning/critical/down) grouped by region or location network. Only counts endpoints that exist in the database.'
      operationId 'getLocationEndpointCounts'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :group_by, in: :query, type: :string, required: false,
                description: 'Group data by specified field',
                enum: [ 'regions', 'locations' ],
                default: 'regions'

      parameter name: :start_time, in: :query, type: :string, required: false,
                description: 'Start time for analysis (ISO 8601 format)'

      parameter name: :end_time, in: :query, type: :string, required: false,
                description: 'End time for analysis (ISO 8601 format)'

      parameter name: :host, in: :query, type: :string, required: false,
                description: 'Filter by hostname'

      parameter name: :endpoint_id, in: :query, type: :integer, required: false,
                description: 'Filter by specific endpoint ID'

      parameter name: :isp, in: :query, type: :string, required: false,
                description: 'Filter by ISP'

      parameter name: :region, in: :query, type: :string, required: false,
                description: 'Filter by region'

      parameter name: :location_id, in: :query, type: :string, required: false,
                description: 'Filter by location network ID'

      parameter name: :device_id, in: :query, type: :string, required: false,
                description: 'Filter by device MAC address'

      parameter name: :router_id, in: :query, type: :integer, required: false,
                description: 'Filter by router inventory ID'

      response '200', 'Successful location endpoint counts grouped by region' do
        schema type: :object,
               properties: {
                 time_window: {
                   type: :object,
                   properties: {
                     start_time: { type: :string, format: 'date-time' },
                     end_time: { type: :string, format: 'date-time' }
                   }
                 },
                 group_by: { type: :string, description: 'Grouping dimension used' },
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       region: { type: :string, description: 'Region name (when grouped by regions)' },
                       location: { type: :string, description: 'Location identifier (when grouped by locations)' },
                       count: { type: :integer, description: 'Total endpoint count' },
                       good: { type: :integer, description: 'Endpoints with good status' },
                       warning: { type: :integer, description: 'Endpoints with warning status' },
                       critical: { type: :integer, description: 'Endpoints with critical status' },
                       down: { type: :integer, description: 'Endpoints with down status' }
                     }
                   }
                 }
               }

        examples 'application/json' => {
          success_response: {
            value: {
              time_window: {
                start_time: '2026-04-01T10:27:25.765Z',
                end_time: '2026-04-02T10:27:25.765Z'
              },
              group_by: 'regions',
              data: [
                {
                  region: 'Delhi',
                  count: 4,
                  good: 2,
                  warning: 0,
                  critical: 1,
                  down: 1
                },
                {
                  region: 'Mumbai',
                  count: 4,
                  good: 1,
                  warning: 0,
                  critical: 0,
                  down: 3
                },
                {
                  region: 'Bangalore',
                  count: 3,
                  good: 0,
                  warning: 1,
                  critical: 2,
                  down: 0
                }
              ]
            }
          }
        }

        let(:'X-AUTH-TOKEN') { 'test_token' }
        let(:group_by) { 'regions' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 3)
          )

          mock_response = {
            time_window: {
              start_time: '2026-04-01T10:27:25.765Z',
              end_time: '2026-04-02T10:27:25.765Z'
            },
            group_by: 'regions',
            data: [
              { region: 'Delhi', count: 4, good: 2, warning: 0, critical: 1, down: 1 },
              { region: 'Mumbai', count: 4, good: 1, warning: 0, critical: 0, down: 3 },
              { region: 'Bangalore', count: 3, good: 0, warning: 1, critical: 2, down: 0 }
            ]
          }

          allow_any_instance_of(LocationEndpointsService).to receive(:call).and_return(mock_response)
        end

        run_test!
      end

      response '200', 'Successful location endpoint counts grouped by locations' do
        schema type: :object,
               properties: {
                 time_window: { type: :object },
                 group_by: { type: :string },
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       location: { type: :string },
                       count: { type: :integer },
                       good: { type: :integer },
                       warning: { type: :integer },
                       critical: { type: :integer },
                       down: { type: :integer }
                     }
                   }
                 }
               }

        let(:'X-AUTH-TOKEN') { 'test_token' }
        let(:group_by) { 'locations' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 3)
          )

          mock_response = {
            time_window: {
              start_time: '2026-04-01T10:27:25.765Z',
              end_time: '2026-04-02T10:27:25.765Z'
            },
            group_by: 'locations',
            data: [
              { location: 'loc-001', count: 5, good: 3, warning: 1, critical: 0, down: 1 },
              { location: 'loc-002', count: 3, good: 2, warning: 0, critical: 1, down: 0 }
            ]
          }

          allow_any_instance_of(LocationEndpointsService).to receive(:call).and_return(mock_response)
        end

        run_test!
      end

      response '401', 'Unauthorized - Invalid or missing authentication token' do
        let(:'X-AUTH-TOKEN') { 'invalid_token' }
        let(:group_by) { 'regions' }

        before do
          allow(User).to receive(:find_by).with(access_token: 'invalid_token').and_return(nil)
        end

        run_test!
      end

      response '500', 'Internal Server Error - Service failure' do
        let(:'X-AUTH-TOKEN') { 'test_token' }
        let(:group_by) { 'regions' }

        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
            create(:admin_user, organisation_id: 3)
          )

          allow_any_instance_of(LocationEndpointsService).to receive(:call)
            .and_raise(StandardError.new('Service error'))
          allow(Rails.logger).to receive(:error)
        end

        run_test! do |response|
          expect(response.status).to eq(500)
        end
      end
    end
  end

  path '/api/v1/dashboard/endpoint_locations' do
    get 'Get endpoint locations/devices' do
      tags 'Dashboard'
      description 'Retrieves endpoint resources from ClickHouse based on group_by'
      operationId 'getEndpointLocations'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :endpoint_id, in: :query, type: :string, required: true,
                description: 'Comma separated endpoint IDs'

      parameter name: :group_by, in: :query, type: :string, required: false,
                description: 'Resource type to return',
                enum: [ 'locations', 'devices' ],
                default: 'locations'

      parameter name: :host, in: :query, type: :string, required: false,
                description: 'Filter by hostname'

      parameter name: :isp, in: :query, type: :string, required: false,
                description: 'Filter by ISP'

      parameter name: :region, in: :query, type: :string, required: false,
                description: 'Filter by region'

      parameter name: :location_id, in: :query, type: :string, required: false,
                description: 'Filter by location network ID'

      parameter name: :device_id, in: :query, type: :string, required: false,
                description: 'Filter by device MAC address'

      parameter name: :router_id, in: :query, type: :integer, required: false,
                description: 'Filter by router inventory ID'

      parameter name: :start_time, in: :query, type: :string, required: false,
                description: 'Start time for analysis (ISO 8601 format)'

      parameter name: :end_time, in: :query, type: :string, required: false,
                description: 'End time for analysis (ISO 8601 format)'

      response '200', 'Successful retrieval of endpoint resources' do
        schema type: :object,
              properties: {
                time_window: {
                  type: :object,
                  description: 'Time window for the analysis',
                  properties: {
                    start_time: {
                      type: :string,
                      format: 'date-time',
                      description: 'Start time of the analysis window'
                    },
                    end_time: {
                      type: :string,
                      format: 'date-time',
                      description: 'End time of the analysis window'
                    }
                  }
                },

                group_by: {
                  type: :string,
                  description: 'Resource type returned',
                  example: 'devices'
                },

                data: {
                  type: :array,
                  description: 'Resources returned based on group_by parameter',
                  items: {
                    type: :object,
                    properties: {
                      id: {
                        type: :integer,
                        description: 'Location network ID or router inventory ID'
                      },

                      name: {
                        type: :string,
                        description: 'Location network name'
                      },

                      mac_id: {
                        type: :string,
                        description: 'Device MAC address'
                      }
                    }
                  }
                }
              }

        examples 'application/json' => {
          locations_response: {
            value: {
              time_window: {
                start_time: '2025-05-25T02:07:52Z',
                end_time: '2026-05-07T07:27:52Z'
              },
              group_by: 'locations',
              data: [
                {
                  id: 685,
                  name: '10th Street Bistro'
                }
              ]
            }
          },

          devices_response: {
            value: {
              time_window: {
                start_time: '2025-05-25T02:07:52Z',
                end_time: '2026-05-07T07:27:52Z'
              },
              group_by: 'devices',
              data: [
                {
                  id: 5002,
                  mac_id: '11:22:33:44:55:66'
                },
                {
                  id: 5001,
                  mac_id: 'AA:BB:CC:DD:EE:11'
                },
                {
                  id: 5003,
                  mac_id: '99:88:77:66:55:44'
                }
              ]
            }
          }
        }

        let(:'X-AUTH-TOKEN') { 'test_token' }
        let(:endpoint_id) { '1,2,3' }
        let(:group_by) { 'locations' }

        before do
          user = create(:admin_user, id: 123, organisation_id: 456)

          create(:endpoint_monitoring_group, user: user)

          allow(Clickhouse::Base.connection)
            .to receive(:select_all)
            .and_return([])

          allow(Clickhouse::Base.connection)
            .to receive(:select_one)
            .and_return({})

          allow_any_instance_of(ApplicationController)
            .to receive(:authenticate_user!)
            .and_return(true)

          allow_any_instance_of(ApplicationController)
            .to receive(:current_user)
            .and_return(user)
        end

        run_test!
      end

      response '400', 'Bad Request - endpoint_id is required' do
        schema type: :object,
              properties: {
                error: {
                  type: :string,
                  example: 'endpoint_id is required'
                }
              }

        let(:'X-AUTH-TOKEN') { 'test_token' }
        let(:endpoint_id) { nil }

        before do
          user = create(:admin_user, id: 123, organisation_id: 456)

          allow_any_instance_of(ApplicationController)
            .to receive(:authenticate_user!)
            .and_return(true)

          allow_any_instance_of(ApplicationController)
            .to receive(:current_user)
            .and_return(user)
        end

        run_test! do |response|
          expect(response.status).to eq(400)

          json = JSON.parse(response.body)

          expect(json['error']).to eq('endpoint_id is required')
        end
      end

      response '401', 'Unauthorized - Invalid or missing authentication token' do
        let(:'X-AUTH-TOKEN') { 'invalid_token' }
        let(:endpoint_id) { '1' }

        before do
          allow(User)
            .to receive(:find_by)
            .with(access_token: 'invalid_token')
            .and_return(nil)
        end

        run_test! do |response|
          expect(response.status).to eq(401)
        end
      end

      response '200', 'No matching endpoint data found' do
        schema type: :object,
              properties: {
                time_window: {
                  type: :object,
                  properties: {
                    start_time: {
                      type: :string,
                      format: 'date-time'
                    },

                    end_time: {
                      type: :string,
                      format: 'date-time'
                    }
                  }
                },

                group_by: {
                  type: :string,
                  example: 'locations'
                },

                data: {
                  type: :array,
                  example: []
                }
              }

        let(:'X-AUTH-TOKEN') { 'test_token' }
        let(:endpoint_id) { '999999' }

        before do
          user = create(:admin_user, id: 123, organisation_id: 456)

          allow(Clickhouse::Base.connection)
            .to receive(:select_all)
            .and_return([])

          allow(Clickhouse::Base.connection)
            .to receive(:select_one)
            .and_return({})

          allow_any_instance_of(ApplicationController)
            .to receive(:authenticate_user!)
            .and_return(true)

          allow_any_instance_of(ApplicationController)
            .to receive(:current_user)
            .and_return(user)
        end

        run_test! do |response|
          expect(response.status).to eq(200)

          json = JSON.parse(response.body)

          expect(json).to have_key('time_window')
          expect(json).to have_key('group_by')
          expect(json).to have_key('data')

          expect(json['data']).to eq([])
        end
      end
    end
  end
end
