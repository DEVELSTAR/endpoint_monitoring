require 'rails_helper'

RSpec.describe Api::V1::DashboardController, type: :request do
  let!(:user) { create(:admin_user, organisation_id: 6) }

  let(:valid_token) { 'valid_test_token' }
  let(:invalid_token) { 'invalid_token' }

  let(:mock_service_response) do
    {
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
          avg_latency_ms: 45.2,
          sample_count: 1500,
          endpoint_count: 1,
          device_count: 3,
          location_count: 2
        }
      ]
    }
  end

  before do
    # Mock User.find_by to return user for valid token, handling potential includes(:role)
    allow(User).to receive(:includes).with(:role).and_return(User)
    allow(User).to receive(:find_by).with(access_token: valid_token).and_return(user)
    allow(User).to receive(:find_by).with(access_token: invalid_token).and_return(nil)
  end

  describe 'GET /api/v1/dashboard/latency_analysis' do
    context 'when authenticated with valid token' do
      let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }

      context 'with successful service response' do
        before do
          allow_any_instance_of(LatencyAnalysisService).to receive(:call).and_return(mock_service_response)
        end

        it 'returns successful response with default parameters' do
          get '/api/v1/dashboard/latency_analysis', headers: headers

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to eq('application/json; charset=utf-8')

          json_response = JSON.parse(response.body)
          expect(json_response).to include(
            'time_window' => hash_including('start_time', 'end_time'),
            'group_by' => 'endpoint_id',
            'response_efficiency' => hash_including('good', 'warning', 'critical', 'total_count'),
            'data' => array_including(
              hash_including('endpoint_id', 'status', 'avg_latency_ms')
            )
          )
        end

        it 'passes correct default parameters to service' do
          expect(LatencyAnalysisService).to receive(:new).with(
            hash_including(
              org_id: 6,
              group_by: 'endpoint_id',
              host: nil,
              endpoint_id: nil,
              isp: nil,
              region: nil,
              location_id: nil,
              device_id: nil,
              router_id: nil,
              sites_type: nil
            )
          ).and_return(double(call: mock_service_response))

          get '/api/v1/dashboard/latency_analysis', headers: headers
        end

        it 'handles custom group_by parameter' do
          expect(LatencyAnalysisService).to receive(:new).with(
            hash_including(group_by: 'isp')
          ).and_return(double(call: mock_service_response))

          get '/api/v1/dashboard/latency_analysis', params: { group_by: 'isp' }, headers: headers
        end

        it 'handles all filter parameters' do
          params = {
            group_by: 'device_id',
            host: 'google.com',
            endpoint_id: '123',
            isp: 'Airtel',
            region: 'Delhi',
            location_id: 'loc_123',
            device_id: 'device_456',
            router_id: 'router_789',
            sites_type: 'good'
          }

          expect(LatencyAnalysisService).to receive(:new).with(
            hash_including(
              org_id: 6,
              group_by: 'device_id',
              host: 'google.com',
              endpoint_id: '123',
              isp: 'Airtel',
              region: 'Delhi',
              location_id: 'loc_123',
              device_id: 'device_456',
              router_id: 'router_789',
              sites_type: 'good'
            )
          ).and_return(double(call: mock_service_response))

          get '/api/v1/dashboard/latency_analysis', params: params, headers: headers
        end

        context 'with time window parameters' do
          it 'handles last_minutes parameter' do
            allow_any_instance_of(Api::V1::DashboardController).to receive(:resolve_time_window)
              .and_return([ Time.parse('2024-11-05T12:00:00Z'), Time.parse('2024-11-06T12:00:00Z') ])
              expect(LatencyAnalysisService).to receive(:new).with(
                hash_including(
                  start_time: Time.parse('2024-11-05T12:00:00Z'),
                  end_time:   Time.parse('2024-11-06T12:00:00Z')
                )
              )
              .and_return(double(call: mock_service_response))

            get '/api/v1/dashboard/latency_analysis',
                params: { last_minutes: 1440 },
                headers: headers
          end

          it 'handles explicit start_time and end_time parameters' do
            allow_any_instance_of(Api::V1::DashboardController).to receive(:resolve_time_window)
              .and_return([ Time.parse('2024-11-01T00:00:00Z'), Time.parse('2024-11-06T23:59:59Z') ])

            expect(LatencyAnalysisService).to receive(:new).with(
              hash_including(
                start_time: Time.parse('2024-11-01T00:00:00Z'),
                end_time:   Time.parse('2024-11-06T23:59:59Z')
              )
            ).and_return(double(call: mock_service_response))

            get '/api/v1/dashboard/latency_analysis',
                params: {
                  start_time: '2024-11-01T00:00:00Z',
                  end_time: '2024-11-06T23:59:59Z'
                },
                headers: headers
          end
        end

        context 'with different group_by options' do
          %w[endpoint_id host device_id region location_id router_id isp isp_region].each do |group_by_option|
            it "handles group_by=#{group_by_option}" do
              expect(LatencyAnalysisService).to receive(:new).with(
                hash_including(group_by: group_by_option)
              ).and_return(double(call: mock_service_response))

              get '/api/v1/dashboard/latency_analysis',
                  params: { group_by: group_by_option },
                  headers: headers

              expect(response).to have_http_status(:ok)
            end
          end
        end

        context 'with different sites_type options' do
          %w[good warning critical down].each do |sites_type|
            it "handles sites_type=#{sites_type}" do
              expect(LatencyAnalysisService).to receive(:new).with(
                hash_including(sites_type: sites_type)
              ).and_return(double(call: mock_service_response))

              get '/api/v1/dashboard/latency_analysis',
                  params: { sites_type: sites_type },
                  headers: headers

              expect(response).to have_http_status(:ok)
            end
          end
        end
      end

      context 'when service raises an exception' do
        before do
          allow_any_instance_of(LatencyAnalysisService).to receive(:call)
            .and_raise(StandardError.new('Service error'))
        end

        it 'handles service exceptions and returns internal server error' do
          expect(Rails.logger).to receive(:error).with(anything)

          get '/api/v1/dashboard/latency_analysis', headers: headers

          expect(response).to have_http_status(:internal_server_error)

          json_response = JSON.parse(response.body)
          expect(json_response).to include(
            'status' => 500,
            'error' => 'Internal Server Error',
            'message' => 'Service error'
          )
        end

        it 'handles database connection errors' do
          allow_any_instance_of(LatencyAnalysisService).to receive(:call)
            .and_raise(StandardError.new('Connection failed'))

          expect(Rails.logger).to receive(:error).with(anything)

          get '/api/v1/dashboard/latency_analysis', headers: headers

          expect(response).to have_http_status(:internal_server_error)

          json_response = JSON.parse(response.body)
          expect(json_response).to include(
            'status' => 500,
            'error' => 'Internal Server Error',
            'message' => 'Connection failed'
          )
        end

        it 'handles timeout errors' do
          allow_any_instance_of(LatencyAnalysisService).to receive(:call)
            .and_raise(Timeout::Error.new('Request timeout'))

          expect(Rails.logger).to receive(:error).with(anything)

          get '/api/v1/dashboard/latency_analysis', headers: headers

          expect(response).to have_http_status(:internal_server_error)

          json_response = JSON.parse(response.body)
          expect(json_response).to include(
            'status' => 500,
            'error' => 'Internal Server Error',
            'message' => 'Request timeout'
          )
        end
      end
    end

    context 'when not authenticated' do
      context 'with missing token' do
        it 'returns unauthorized error' do
          get '/api/v1/dashboard/latency_analysis'

          expect(response).to have_http_status(:unauthorized)

          json_response = JSON.parse(response.body)
          expect(json_response).to eq({ 'error' => 'Unauthorized' })
        end
      end

      context 'with invalid token' do
        let(:headers) { { 'X-AUTH-TOKEN' => invalid_token } }

        it 'returns unauthorized error' do
          get '/api/v1/dashboard/latency_analysis', headers: headers

          expect(response).to have_http_status(:unauthorized)
          expect(response.body).to be_empty
        end
      end

      context 'with token in params instead of headers' do
        it 'authenticates successfully with valid token in params' do
          allow_any_instance_of(LatencyAnalysisService).to receive(:call).and_return(mock_service_response)

          get '/api/v1/dashboard/latency_analysis', params: { access_token: valid_token }

          expect(response).to have_http_status(:ok)
        end

        it 'returns unauthorized with invalid token in params' do
          get '/api/v1/dashboard/latency_analysis', params: { access_token: invalid_token }

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when user has no organisation_id' do
      let!(:user_without_org) { create(:admin_user, organisation_id: nil) }
      let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }

      before do
        allow(User).to receive(:find_by).with(access_token: valid_token).and_return(user_without_org)
      end

      it 'returns bad request error' do
        get '/api/v1/dashboard/latency_analysis', headers: headers

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response).to eq({ 'error' => 'org_id is required' })
      end
    end

    context 'edge cases and parameter validation' do
      let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }

      before do
        allow_any_instance_of(LatencyAnalysisService).to receive(:call).and_return(mock_service_response)
      end

      it 'handles nil group_by parameter (defaults to endpoint_id)' do
        # When group_by is not provided, it should default to 'endpoint_id'
        service_double = double(call: mock_service_response)
        allow(LatencyAnalysisService).to receive(:new).and_return(service_double)

        get '/api/v1/dashboard/latency_analysis', headers: headers

        expect(response).to have_http_status(:ok)

        # Verify that the service was called with the default group_by
        expect(LatencyAnalysisService).to have_received(:new).with(
          hash_including(group_by: 'endpoint_id')
        )
      end

      it 'handles empty string parameters' do
        params = {
          group_by: '',
          host: '',
          isp: '',
          region: ''
        }

        # Empty string group_by will be passed as-is (|| only works for nil, not empty string)
        service_double = double(call: mock_service_response)
        allow(LatencyAnalysisService).to receive(:new).and_return(service_double)

        get '/api/v1/dashboard/latency_analysis', params: params, headers: headers

        expect(response).to have_http_status(:ok)

        # Verify that the service was called with the correct parameters
        expect(LatencyAnalysisService).to have_received(:new).with(
          hash_including(
            group_by: '',  # Empty string is passed as-is
            host: '',
            isp: '',
            region: ''
          )
        )
      end

      it 'handles numeric string parameters' do
        params = {
          endpoint_id: '123',
          location_id: '456',
          device_id: '789'
        }

        expect(LatencyAnalysisService).to receive(:new).with(
          hash_including(
            endpoint_id: '123',
            location_id: '456',
            device_id: '789'
          )
        ).and_return(double(call: mock_service_response))

        get '/api/v1/dashboard/latency_analysis', params: params, headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'handles special characters in filter parameters' do
        params = {
          host: 'test-host.example.com',
          isp: 'AT&T',
          region: 'New York'
        }

        expect(LatencyAnalysisService).to receive(:new).with(
          hash_including(
            host: 'test-host.example.com',
            isp: 'AT&T',
            region: 'New York'
          )
        ).and_return(double(call: mock_service_response))

        get '/api/v1/dashboard/latency_analysis', params: params, headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'response format validation' do
      let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }

      before do
        allow_any_instance_of(LatencyAnalysisService).to receive(:call).and_return(mock_service_response)
      end

      it 'returns JSON content type' do
        get '/api/v1/dashboard/latency_analysis', headers: headers

        expect(response.content_type).to eq('application/json; charset=utf-8')
      end

      it 'returns expected response structure' do
        get '/api/v1/dashboard/latency_analysis', headers: headers

        json_response = JSON.parse(response.body)

        # Validate top-level structure
        expect(json_response.keys).to match_array(%w[time_window group_by response_efficiency data])

        # Validate time_window structure
        expect(json_response['time_window']).to include('start_time', 'end_time')

        # Validate response_efficiency structure
        expect(json_response['response_efficiency']).to include('good', 'warning', 'critical', 'down', 'total_count')

        # Validate data array structure
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].first).to include(
          'endpoint_id', 'status', 'avg_latency_ms',
          'sample_count', 'endpoint_count', 'device_count', 'location_count'
        )
      end
    end
  end

  describe 'GET /api/v1/dashboard/endpoint_reports' do
    let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }
    let(:mock_reports_response) do
      {
        time_window: { start_time: '2024-11-01T00:00:00Z', end_time: '2024-11-06T23:59:59Z' },
        group_by: 'endpoint_id',
        summary: { good: 100.0, critical: 0.0, down: 0.0 },
        metrics: [
          { time: '2024-11-01T00:00:00Z', good: 100.0, critical: 0.0, down: 0.0 }
        ]
      }
    end

    context 'when authenticated' do
      before do
        allow_any_instance_of(EndpointReportsService).to receive(:call).and_return(mock_reports_response)
      end

      it 'returns successful response' do
        get '/api/v1/dashboard/endpoint_reports', headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('time_window', 'group_by', 'summary', 'metrics')
      end

      it 'passes group_by parameter to service' do
        expect(EndpointReportsService).to receive(:new).with(
          hash_including(group_by: 'host')
        ).and_return(double(call: mock_reports_response))

        get '/api/v1/dashboard/endpoint_reports', params: { group_by: 'host' }, headers: headers
      end

      it 'handles service exceptions' do
        allow_any_instance_of(EndpointReportsService).to receive(:call)
          .and_raise(StandardError.new('Service error'))
        expect(Rails.logger).to receive(:error).with(anything)

        get '/api/v1/dashboard/endpoint_reports', headers: headers
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized error' do
        get '/api/v1/dashboard/endpoint_reports'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/dashboard/site_distribution' do
    let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }
    let(:mock_site_response) do
      {
        time_window: { start_time: '2024-11-01T00:00:00Z', end_time: '2024-11-06T23:59:59Z' },
        bucket_size: 20,
        summary: { total_sites: 50, total_good_sites: 30, total_warning_sites: 15, total_critical_sites: 5 },
        distribution: [ { latency_range: '0-20', total_sites: 30 } ]
      }
    end

    context 'when authenticated' do
      before do
        allow_any_instance_of(SiteDistributionService).to receive(:call).and_return(mock_site_response)
      end

      it 'returns successful response' do
        get '/api/v1/dashboard/site_distribution', headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('time_window', 'bucket_size', 'summary', 'distribution')
      end

      it 'handles bucket_size parameter' do
        expect(SiteDistributionService).to receive(:new).with(
          hash_including(bucket_size: '50')
        ).and_return(double(call: mock_site_response))

        get '/api/v1/dashboard/site_distribution', params: { bucket_size: '50' }, headers: headers
      end

      it 'handles service exceptions' do
        allow_any_instance_of(SiteDistributionService).to receive(:call)
          .and_raise(StandardError.new('Service error'))
        expect(Rails.logger).to receive(:error).with(anything)

        get '/api/v1/dashboard/site_distribution', headers: headers
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized error' do
        get '/api/v1/dashboard/site_distribution'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/dashboard/endpoint_metrics' do
    let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }
    let(:mock_metrics_response) do
      {
        group_by: 'endpoint_id',
        endpoint: { id: 123, name: 'google.com', monitoring_mode: 'http' },
        time_window: { start_time: '2024-11-01T00:00:00Z', end_time: '2024-11-06T23:59:59Z' },
        summary: { total_groups: 10, total_samples: 1000, avg_latency: 45.2 },
        metrics: [],
        pagination: { current_page: 1, per_page: 10, total_count: 0, total_pages: 0 }
      }
    end

    context 'when authenticated' do
      before do
        allow_any_instance_of(EndpointMetricsService).to receive(:call).and_return(mock_metrics_response)
      end

      it 'returns successful response with default group_by' do
        expect(EndpointMetricsService).to receive(:new).with(
          hash_including(group_by: 'endpoint_id', endpoint_id: '123')
        ).and_return(double(call: mock_metrics_response))

        get '/api/v1/dashboard/endpoint_metrics', params: { endpoint_id: '123' }, headers: headers
        expect(response).to have_http_status(:ok)
      end

      it 'handles pagination parameters' do
        expect(EndpointMetricsService).to receive(:new).with(
          hash_including(page: '3', per_page: '20', endpoint_id: '123')
        ).and_return(double(call: mock_metrics_response))

        get '/api/v1/dashboard/endpoint_metrics',
            params: { page: '3', per_page: '20', endpoint_id: '123' },
            headers: headers
      end
    end
  end

  describe 'GET /api/v1/dashboard/grouped_timeseries' do
    let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }
    let(:mock_grouped_timeseries_response) do
      {
        time_window: {
          start_time: '2024-11-01T00:00:00Z',
          end_time: '2024-11-06T23:59:59Z',
          bucket_minutes: 5
        },
        filters: {
          endpoint_id: '2',
          host: 'google.com'
        },
        summary: {
          total_data_points: 288,
          good_points: 280,
          warning_points: 8,
          critical_points: 0,
          down_points: 0,
          good_percentage: 97.2,
          warning_percentage: 2.8,
          critical_percentage: 0.0,
          down_percentage: 0.0,
          total_samples: 1440,
          endpoint_count: 1,
          device_count: 2,
          host_count: 1,
          region_count: 1,
          isp_count: 2,
          location_network_count: 1,
          router_inventory_count: 1,
          average_latency_ms: 35.42
        },
        overview: 'Analysis across 1 endpoint, 2 devices, 1 host demonstrates good performance with 97.2% of periods showing fast response times.',
        timeseries: [
          {
            timestamp: '2024-11-06T12:00:00Z',
            time_ago: '2h ago',
            avg_latency_ms: 33.6,
            sample_count: 5,
            status: 'good'
          }
        ]
      }
    end

    describe 'Authentication & Authorization' do
      it 'returns 401 when no authentication token provided' do
        get '/api/v1/dashboard/grouped_timeseries'

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq({ 'error' => 'Unauthorized' })
      end

      it 'returns 401 when invalid token provided' do
        get '/api/v1/dashboard/grouped_timeseries',
            headers: { 'X-AUTH-TOKEN' => invalid_token }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'accepts token in header' do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)

        get '/api/v1/dashboard/grouped_timeseries',
            headers: { 'X-AUTH-TOKEN' => valid_token }

        expect(response).to have_http_status(:ok)
      end

      it 'accepts token as parameter' do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)

        get '/api/v1/dashboard/grouped_timeseries',
            params: { access_token: valid_token }

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'Filter Options' do
      before do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)
      end

      context 'when filtering by endpoint_id' do
        it 'returns successful response' do
          get '/api/v1/dashboard/grouped_timeseries',
              params: { endpoint_id: '2' },
              headers: headers

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['filters']).to include('endpoint_id')
          expect(json_response).to include('time_window', 'filters', 'summary', 'overview', 'timeseries')
        end

        it 'passes endpoint_id filter to service' do
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(endpoint_id: '2')
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries',
              params: { endpoint_id: '2' },
              headers: headers
        end
      end

      context 'when filtering by host' do
        it 'returns successful response' do
          get '/api/v1/dashboard/grouped_timeseries',
              params: { host: 'youtube.com' },
              headers: headers

          expect(response).to have_http_status(:ok)
        end

        it 'passes host filter to service' do
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(host: 'youtube.com')
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries',
              params: { host: 'youtube.com' },
              headers: headers
        end
      end

      context 'when filtering by isp' do
        it 'returns successful response' do
          get '/api/v1/dashboard/grouped_timeseries',
              params: { isp: 'Jio' },
              headers: headers

          expect(response).to have_http_status(:ok)
        end

        it 'passes isp filter to service' do
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(isp: 'Jio')
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries',
              params: { isp: 'Jio' },
              headers: headers
        end
      end

      context 'when filtering by region' do
        it 'returns successful response' do
          get '/api/v1/dashboard/grouped_timeseries',
              params: { region: 'KA' },
              headers: headers

          expect(response).to have_http_status(:ok)
        end

        it 'passes region filter to service' do
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(region: 'KA')
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries',
              params: { region: 'KA' },
              headers: headers
        end
      end

      context 'when filtering by device_id' do
        it 'returns successful response' do
          get '/api/v1/dashboard/grouped_timeseries',
              params: { device_id: 'dev-1' },
              headers: headers

          expect(response).to have_http_status(:ok)
        end

        it 'passes device_id filter to service' do
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(device_id: 'dev-1')
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries',
              params: { device_id: 'dev-1' },
              headers: headers
        end
      end

      context 'when filtering by location_id' do
        it 'returns successful response' do
          get '/api/v1/dashboard/grouped_timeseries',
              params: { location_id: 'L1' },
              headers: headers

          expect(response).to have_http_status(:ok)
        end

        it 'passes location_id filter to service' do
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(location_id: 'L1')
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries',
              params: { location_id: 'L1' },
              headers: headers
        end
      end

      context 'when filtering by router_id' do
        it 'returns successful response' do
          get '/api/v1/dashboard/grouped_timeseries',
              params: { router_id: 'R1' },
              headers: headers

          expect(response).to have_http_status(:ok)
        end

        it 'passes router_id filter to service' do
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(router_id: 'R1')
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries',
              params: { router_id: 'R1' },
              headers: headers
        end
      end

      context 'when no filters provided' do
        it 'returns successful response with no filters' do
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(org_id: 6)
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries', headers: headers

          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe 'Filter Combinations' do
      before do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)
      end

      it 'handles multiple filters together' do
        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(
            region: 'KA',
            isp: 'Jio',
            host: 'google.com',
            device_id: 'dev-1'
          )
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: {
              region: 'KA',
              isp: 'Jio',
              host: 'google.com',
              device_id: 'dev-1'
            },
            headers: headers
      end

      it 'handles all available filters' do
        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(
            host: 'youtube.com',
            endpoint_id: '2',
            device_id: 'dev-1',
            isp: 'Airtel',
            region: 'MH',
            location_id: 'L1',
            router_id: 'R1'
          )
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: {
              host: 'youtube.com',
              endpoint_id: '2',
              device_id: 'dev-1',
              isp: 'Airtel',
              region: 'MH',
              location_id: 'L1',
              router_id: 'R1'
            },
            headers: headers
      end
    end

    describe 'Time Window Parameters' do
      before do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)
      end

      it 'handles last_minutes parameter' do
        allow_any_instance_of(Api::V1::DashboardController).to receive(:resolve_time_window)
          .and_return([ Time.parse('2024-11-06T10:00:00Z'), Time.parse('2024-11-06T12:00:00Z') ])

        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(
            start_time: Time.parse('2024-11-06T10:00:00Z'),
            end_time: Time.parse('2024-11-06T12:00:00Z')
          )
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: { last_minutes: 120 },
            headers: headers
      end

      it 'handles explicit start_time and end_time' do
        allow_any_instance_of(Api::V1::DashboardController).to receive(:resolve_time_window)
          .and_return([ Time.parse('2024-11-01T00:00:00Z'), Time.parse('2024-11-06T23:59:59Z') ])

        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(
            start_time: Time.parse('2024-11-01T00:00:00Z'),
            end_time: Time.parse('2024-11-06T23:59:59Z')
          )
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: {
              start_time: '2024-11-01T00:00:00Z',
              end_time: '2024-11-06T23:59:59Z'
            },
            headers: headers
      end

      it 'uses default time window when no time params provided' do
        allow_any_instance_of(Api::V1::DashboardController).to receive(:resolve_time_window)
          .and_return([ 24.hours.ago, Time.current ])

        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'endpoint_id' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'Bucket Minutes Parameter' do
      before do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)
      end

      it 'handles explicit bucket_minutes parameter' do
        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(bucket_minutes: '5')
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'endpoint_id', bucket_minutes: 5 },
            headers: headers
      end

      it 'handles different bucket_minutes values' do
        [ 1, 5, 15, 60, 360, 1440 ].each do |bucket|
          expect(GroupedTimeseriesService).to receive(:new).with(
            hash_including(bucket_minutes: bucket.to_s)
          ).and_return(double(call: mock_grouped_timeseries_response))

          get '/api/v1/dashboard/grouped_timeseries',
              params: { group_by: 'endpoint_id', bucket_minutes: bucket },
              headers: headers
        end
      end

      it 'auto-calculates bucket_minutes when not provided' do
        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'endpoint_id' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'Sites Type Filter' do
      before do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)
      end

      it 'handles sites_type=fast' do
        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(sites_type: 'good')
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'endpoint_id', sites_type: 'good' },
            headers: headers
      end

      it 'handles sites_type=warning' do
        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(sites_type: 'warning')
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'endpoint_id', sites_type: 'warning' },
            headers: headers
      end

      it 'handles sites_type=slow' do
        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(sites_type: 'critical')
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'endpoint_id', sites_type: 'critical' },
            headers: headers
      end
    end

    describe 'Response Structure' do
      before do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)
      end

      it 'returns correct top-level structure' do
        get '/api/v1/dashboard/grouped_timeseries',
            headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response.keys).to match_array([ 'time_window', 'filters', 'summary', 'overview', 'timeseries' ])
      end

      it 'includes time_window with required fields' do
        get '/api/v1/dashboard/grouped_timeseries',
            headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response['time_window']).to include('start_time', 'end_time', 'bucket_minutes')
      end

      it 'includes summary with all count fields' do
        get '/api/v1/dashboard/grouped_timeseries',
            headers: headers

        json_response = JSON.parse(response.body)
        summary = json_response['summary']
        expect(summary).to include(
          'total_data_points',
          'good_percentage',
          'warning_percentage',
          'critical_percentage',
          'down_percentage',
          'total_samples',
          'endpoint_count',
          'device_count',
          'host_count',
          'region_count',
          'isp_count',
          'location_network_count',
          'router_inventory_count',
          'average_latency_ms'
        )
      end

      it 'includes overview string' do
        get '/api/v1/dashboard/grouped_timeseries',
            headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response['overview']).to be_a(String)
        expect(json_response['overview'].length).to be > 0
      end

      it 'includes timeseries array with proper structure' do
        get '/api/v1/dashboard/grouped_timeseries',
            headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response['timeseries']).to be_an(Array)

        if json_response['timeseries'].any?
          first_point = json_response['timeseries'].first
          expect(first_point).to include('timestamp', 'time_ago', 'avg_latency_ms', 'sample_count', 'status')
        end
      end
    end

    describe 'Error Handling' do
      it 'handles service exceptions gracefully' do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call)
          .and_raise(StandardError.new('Database connection failed'))
        expect(Rails.logger).to receive(:error).with(anything)

        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'endpoint_id' },
            headers: headers

        expect(response).to have_http_status(:internal_server_error)
      end

      it 'handles empty results gracefully' do
        empty_response = mock_grouped_timeseries_response.merge(
          timeseries: [],
          summary: mock_grouped_timeseries_response[:summary].merge(total_data_points: 0)
        )
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(empty_response)

        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'endpoint_id' },
            headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['timeseries']).to eq([])
        expect(json_response['summary']['total_data_points']).to eq(0)
      end

      it 'handles special characters in filter values' do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)

        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(host: "google's-server.com")
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: { group_by: 'host', host: "google's-server.com" },
            headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'Integration Tests' do
      before do
        allow_any_instance_of(GroupedTimeseriesService).to receive(:call).and_return(mock_grouped_timeseries_response)
      end

      it 'handles complete real-world request with all parameters' do
        expect(GroupedTimeseriesService).to receive(:new).with(
          hash_including(
            org_id: 6,
            bucket_minutes: '60',
            sites_type: 'good',
            host: 'google.com',
            endpoint_id: '2',
            device_id: 'dev-1',
            isp: 'Jio',
            region: 'KA',
            location_id: 'L1',
            router_id: 'R1'
          )
        ).and_return(double(call: mock_grouped_timeseries_response))

        get '/api/v1/dashboard/grouped_timeseries',
            params: {
              bucket_minutes: 60,
              sites_type: 'good',
              host: 'google.com',
              endpoint_id: '2',
              device_id: 'dev-1',
              isp: 'Jio',
              region: 'KA',
              location_id: 'L1',
              router_id: 'R1',
              last_minutes: 10000
            },
            headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('time_window', 'filters', 'summary', 'overview', 'timeseries')
      end
    end
  end


  describe 'GET /api/v1/dashboard/uplink_timeseries' do
    let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }
    let(:mock_uplink_response) do
      {
        time_window: { start_time: '2024-11-01T00:00:00Z', bucket_minutes: 1 },
        device: { device_id: 'device123' },
        latency: [ { uplink_id: 'uplink1', timeseries: [] } ],
        loss: [ { uplink_id: 'uplink1', timeseries: [] } ]
      }
    end

    context 'when authenticated' do
      before do
        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(mock_uplink_response)
      end

      it 'returns successful response when required params provided' do
        get '/api/v1/dashboard/uplink_timeseries',
            params: { device_id: 'device123' },
            headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('time_window', 'device', 'latency', 'loss')
      end

      it 'returns bad request when device_id missing' do
        get '/api/v1/dashboard/uplink_timeseries',
            headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq({ 'error' => 'device_id is required' })
      end

      it 'handles optional uplink parameters' do
        expect(UplinkTimeseriesService).to receive(:new).with(
          hash_including(
            uplink_id: 'uplink1',
            uplink_type: 'primary',
            bucket_minutes: '5'
          )
        ).and_return(double(call: mock_uplink_response))

        get '/api/v1/dashboard/uplink_timeseries',
            params: {
              device_id: 'device123',
              uplink_id: 'uplink1',
              uplink_type: 'primary',
              bucket_minutes: '5'
            },
            headers: headers
      end
    end
  end

  describe 'GET /api/v1/dashboard/location_endpoints' do
    let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }
    let(:mock_location_endpoints_response) do
      {
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
    end

    context 'when authenticated' do
      before do
        allow_any_instance_of(LocationEndpointsService).to receive(:call).and_return(mock_location_endpoints_response)
      end

      it 'returns successful response with default group_by' do
        expect(LocationEndpointsService).to receive(:new).with(
          hash_including(
            org_id: 6,
            group_by: 'regions'
          )
        ).and_return(double(call: mock_location_endpoints_response))

        get '/api/v1/dashboard/location_endpoints', headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('time_window', 'group_by', 'data')
        expect(json_response['group_by']).to eq('regions')
        expect(json_response['data']).to be_an(Array)
      end

      it 'handles group_by=regions parameter' do
        expect(LocationEndpointsService).to receive(:new).with(
          hash_including(group_by: 'regions')
        ).and_return(double(call: mock_location_endpoints_response))

        get '/api/v1/dashboard/location_endpoints', params: { group_by: 'regions' }, headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['group_by']).to eq('regions')
      end

      it 'handles group_by=locations parameter' do
        mock_network_response = {
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

        expect(LocationEndpointsService).to receive(:new).with(
          hash_including(group_by: 'locations')
        ).and_return(double(call: mock_network_response))

        get '/api/v1/dashboard/location_endpoints', params: { group_by: 'locations' }, headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['group_by']).to eq('locations')
        expect(json_response['data'].first).to have_key('location')
      end

      it 'passes time window parameters to service' do
        expect(LocationEndpointsService).to receive(:new).with(
          hash_including(
            start_time: Time.parse('2026-04-01T00:00:00Z'),
            end_time: Time.parse('2026-04-02T00:00:00Z')
          )
        ).and_return(double(call: mock_location_endpoints_response))

        get '/api/v1/dashboard/location_endpoints',
            params: {
              start_time: '2026-04-01T00:00:00Z',
              end_time: '2026-04-02T00:00:00Z'
            },
            headers: headers
      end

      it 'returns correct location data structure' do
        get '/api/v1/dashboard/location_endpoints', headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        # Validate top-level structure
        expect(json_response.keys).to match_array(%w[time_window group_by data])

        # Validate time_window structure
        expect(json_response['time_window']).to include('start_time', 'end_time')

        # Validate data array
        expect(json_response['data']).to be_an(Array)

        # Validate data entry structure
        location = json_response['data'].first
        expect(location).to include('region', 'count', 'good', 'warning', 'critical', 'down')
      end

      context 'with empty locations data' do
        before do
          allow_any_instance_of(LocationEndpointsService).to receive(:call).and_return(
            {
              time_window: {
                start_time: '2026-04-01T10:27:25.765Z',
                end_time: '2026-04-02T10:27:25.765Z'
              },
              group_by: 'region',
              data: []
            }
          )
        end

        it 'returns empty data array when no data' do
          get '/api/v1/dashboard/location_endpoints', headers: headers

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['data']).to eq([])
        end
      end

      context 'when service raises an exception' do
        before do
          allow_any_instance_of(LocationEndpointsService).to receive(:call)
            .and_raise(StandardError.new('Service error'))
        end

        it 'handles service exceptions and returns internal server error' do
          expect(Rails.logger).to receive(:error).with(anything)

          get '/api/v1/dashboard/location_endpoints', headers: headers

          expect(response).to have_http_status(:internal_server_error)
          json_response = JSON.parse(response.body)
          expect(json_response).to include(
            'status' => 500,
            'error' => 'Internal Server Error',
            'message' => 'Service error'
          )
        end
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized error without token' do
        get '/api/v1/dashboard/location_endpoints'

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq({ 'error' => 'Unauthorized' })
      end

      it 'returns unauthorized error with invalid token' do
        get '/api/v1/dashboard/location_endpoints', headers: { 'X-AUTH-TOKEN' => invalid_token }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user has no organisation_id' do
      let!(:user_without_org) { create(:admin_user, organisation_id: nil) }

      before do
        allow(User).to receive(:find_by).with(access_token: valid_token).and_return(user_without_org)
      end

      it 'returns bad request error' do
        get '/api/v1/dashboard/location_endpoints', headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq({ 'error' => 'org_id is required' })
      end
    end
  end

  # Test private methods through public interface
  describe 'private methods' do
    let(:controller) { Api::V1::DashboardController.new }
    let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }

    describe '#resolve_time_window' do
      it 'handles last_minutes parameter' do
        allow_any_instance_of(LatencyAnalysisService).to receive(:call).and_return(mock_service_response)

        # Mock Time.current to get predictable results
        current_time = Time.parse('2024-11-06T12:00:00Z')
        allow(Time).to receive(:current).and_return(current_time)

        get '/api/v1/dashboard/latency_analysis',
            params: { last_minutes: 60 },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'handles explicit start_time and end_time' do
        allow_any_instance_of(LatencyAnalysisService).to receive(:call).and_return(mock_service_response)

        get '/api/v1/dashboard/latency_analysis',
            params: {
              start_time: '2024-11-01T00:00:00Z',
              end_time: '2024-11-06T23:59:59Z'
            },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'uses default time window when no time params provided' do
        allow_any_instance_of(LatencyAnalysisService).to receive(:call).and_return(mock_service_response)

        get '/api/v1/dashboard/latency_analysis', headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    describe '#build_common_filters' do
      it 'builds filters correctly through service calls' do
        expect(LatencyAnalysisService).to receive(:new).with(
          hash_including(
            org_id: 6,
            host: 'google.com',
            endpoint_id: '123',
            isp: 'Airtel',
            region: 'Delhi',
            location_id: 'loc123',
            device_id: 'device456',
            router_id: 'router789',
            sites_type: 'good'
          )
        ).and_return(double(call: mock_service_response))

        get '/api/v1/dashboard/latency_analysis',
            params: {
              host: 'google.com',
              endpoint_id: '123',
              isp: 'Airtel',
              region: 'Delhi',
              location_id: 'loc123',
              device_id: 'device456',
              router_id: 'router789',
              sites_type: 'good'
            },
            headers: headers
      end
    end

    describe '#render_internal_error' do
      it 'logs error and returns structured error response' do
        allow_any_instance_of(LatencyAnalysisService).to receive(:call)
          .and_raise(StandardError.new('Test error message'))

        expect(Rails.logger).to receive(:error).with(anything)

        get '/api/v1/dashboard/latency_analysis', headers: headers

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response).to include(
          'status' => 500,
          'error' => 'Internal Server Error',
          'message' => 'Test error message'
        )
      end
    end
  end

  describe 'GET /api/v1/dashboard/endpoint_locations' do
    subject { get '/api/v1/dashboard/endpoint_locations', params: params, headers: headers }

    let!(:group) { create(:endpoint_monitoring_group, user: user) }
    let!(:endpoint) { create(:endpoint_monitoring_endpoint, host: 'google.com', endpoint_monitoring_group: group) }
    let(:params) { { endpoint_id: endpoint.id } }

    before do
      # Create config mappings for networks and devices
      create(:ep_config_mapping,
             endpoint_monitoring_group: group,
             resourceable_type: 'LocationNetwork',
             resourceable_id: 1)
      create(:ep_config_mapping,
             endpoint_monitoring_group: group,
             resourceable_type: 'RouterInventory',
             resourceable_id: 1)

      # Create actual resources
      create(:location_network, id: 1, network_name: 'Office Network')
      create(:router_inventory, id: 1, mac_id: '00:11:22:33:44:55')

      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    end

    it 'returns endpoint resources successfully' do
      subject
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('time_window')
      expect(json).to have_key('group_by')
      expect(json['group_by']).to eq('locations')
    end

    it 'includes data array' do
      subject
      json = JSON.parse(response.body)
      expect(json).to have_key('data')
      expect(json['data']).to be_an(Array)
    end

    context 'with group_by=devices filter' do
      let(:params) { { endpoint_id: endpoint.id, group_by: 'devices' } }

      it 'includes devices' do
        subject
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end
    end

    context 'with group_by=locations filter' do
      let(:params) { { endpoint_id: endpoint.id, group_by: 'locations' } }

      it 'returns only locations' do
        subject
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end
    end

    context 'when endpoint_id is missing' do
      let(:params) { {} }

      it 'returns 400 bad request' do
        subject
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('endpoint_id is required')
      end
    end

    context 'when endpoint does not exist' do
      let(:params) { { endpoint_id: 999999 } }

      it 'processes successfully but returns empty data' do
        subject
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key('time_window')
        expect(json).to have_key('group_by')
      end
    end

    context 'when user does not own the endpoint' do
      let!(:other_user) { create(:user) }
      let!(:other_group) { create(:endpoint_monitoring_group, user: other_user) }
      let!(:other_endpoint) { create(:endpoint_monitoring_endpoint, endpoint_monitoring_group: other_group) }
      let(:params) { { endpoint_id: other_endpoint.id } }

      it 'processes successfully but returns empty data' do
        subject
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key('time_window')
        expect(json).to have_key('group_by')
      end
    end
  end
end
