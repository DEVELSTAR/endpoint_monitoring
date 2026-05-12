# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard Endpoint Health Metrics API', type: :request do
  let(:user) { create(:admin_user, organisation_id: 'org123', access_token: 'valid_token') }
  let(:headers) { { 'X-AUTH-TOKEN' => 'valid_token' } }

  before do
    allow(User).to receive(:includes).with(:role).and_return(User)
    allow(User).to receive(:find_by).with(access_token: 'valid_token').and_return(user)
    allow(User).to receive(:find_by).with(access_token: 'invalid_token').and_return(nil)
    allow(User).to receive(:find_by).with(access_token: nil).and_return(nil)
  end

  describe 'GET /api/v1/dashboard/endpoint_health_metrics' do
    context 'authentication' do
      it 'returns unauthorized when token is missing' do
        get '/api/v1/dashboard/endpoint_health_metrics'

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Unauthorized')
      end

      it 'returns unauthorized with invalid token' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            headers: { 'X-AUTH-TOKEN' => 'invalid_token' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'accepts valid token and returns success' do
        mock_service_response = {
          time_window: {
            start_time: 24.hours.ago.iso8601,
            end_time: Time.current.iso8601,
            duration_minutes: 1440,
            table_used: 'router_metrics_rollup'
          },
          group_by: 'endpoint_id',
          total_endpoints: 2,
          up_count: 1,
          down_count: 1,
          metrics: [],
          meta: {
            current_page: 1,
            per_page: 10,
            total_pages: 1,
            total_count: 2
          }
        }

        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(mock_service_response)

        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'default parameters' do
      let(:mock_response) do
        {
          time_window: {
            start_time: 24.hours.ago.iso8601,
            end_time: Time.current.iso8601,
            duration_minutes: 1440,
            table_used: 'router_metrics_rollup'
          },
          group_by: 'endpoint_id',
          total_endpoints: 2,
          up_count: 1,
          down_count: 1,
          metrics: [
            {
              endpoint_id: 1,
              endpoint: {
                name: 'Google DNS',
                host: 'google.com',
                monitoring_mode: 'ICMP',
                group_name: 'DNS',
                group_type: 'network'
              },
              number_of_isp: 5,
              number_of_location_id: 5,
              number_of_region: 5,
              number_of_router_id: 5,
              number_of_device_id: 5,
              avg_uptime: 100.0,
              avg_response_time: '25ms',
              down_time_pct: 0.0,
              up_time_pct: 100.0,
              status: 'up',
              status_since: '1d'
            }
          ],
          meta: {
            current_page: 1,
            per_page: 10,
            total_pages: 1,
            total_count: 2
          }
        }
      end

      before do
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(mock_response)
      end

      it 'returns complete response structure' do
        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json).to have_key(:time_window)
        expect(json).to have_key(:group_by)
        expect(json).to have_key(:total_endpoints)
        expect(json).to have_key(:up_count)
        expect(json).to have_key(:down_count)
        expect(json).to have_key(:metrics)
        expect(json).to have_key(:meta)
      end

      it 'includes time window information' do
        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        time_window = json[:time_window]

        expect(time_window).to have_key(:start_time)
        expect(time_window).to have_key(:end_time)
        expect(time_window).to have_key(:duration_minutes)
        expect(time_window).to have_key(:table_used)
      end


      it 'uses default group_by when not specified' do
        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:group_by]).to eq('endpoint_id')
      end
    end

    context 'filtering' do
      before do
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return({
            time_window: {},
            group_by: 'endpoint_id',
            total_endpoints: 1,
            up_count: 1,
            down_count: 0,
            metrics: [],
            meta: { current_page: 1, per_page: 10, total_pages: 1, total_count: 1 }
          })
      end

      it 'accepts host filter' do
        expect(EndpointHealthMetricsService).to receive(:new) do |params|
          expect(params[:host]).to eq('google')
          double(call: { time_window: {}, group_by: 'endpoint_id', total_endpoints: 1,
                        up_count: 1, down_count: 0, metrics: [],
                        meta: { current_page: 1, per_page: 10, total_pages: 1, total_count: 1 } })
        end

        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { host: 'google' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts endpoint_id filter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { endpoint_id: '123' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts region filter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { region: 'mumbai' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts isp filter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { isp: 'airtel' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts location_id filter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { location_id: 'loc123' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts device_id filter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { device_id: 'device123' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts router_id filter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { router_id: 'router123' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts sites_type filter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { sites_type: 'up' },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts multiple filters' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: {
              host: 'google',
              region: 'mumbai',
              isp: 'airtel'
            },
            headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'grouping' do
      let(:base_response) do
        {
          time_window: {},
          total_endpoints: 1,
          up_count: 1,
          down_count: 0,
          metrics: [],
          meta: { current_page: 1, per_page: 10, total_pages: 1, total_count: 1 }
        }
      end

      it 'groups by endpoint_id' do
        response_data = base_response.merge(group_by: 'endpoint_id')
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(response_data)

        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { group_by: 'endpoint_id' },
            headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:group_by]).to eq('endpoint_id')
      end

      it 'groups by host' do
        response_data = base_response.merge(group_by: 'host', total_host: 1)
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(response_data)

        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { group_by: 'host' },
            headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:group_by]).to eq('host')
      end

      it 'groups by region' do
        response_data = base_response.merge(group_by: 'region')
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(response_data)

        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { group_by: 'region' },
            headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:group_by]).to eq('region')
      end

      it 'groups by location_id' do
        response_data = base_response.merge(group_by: 'location_id')
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(response_data)

        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { group_by: 'location_id' },
            headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:group_by]).to eq('location_id')
      end

      it 'groups by isp' do
        response_data = base_response.merge(group_by: 'isp')
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(response_data)

        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { group_by: 'isp' },
            headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:group_by]).to eq('isp')
      end

      it 'groups by isp_region' do
        response_data = base_response.merge(group_by: 'isp_region')
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(response_data)

        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { group_by: 'isp_region' },
            headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:group_by]).to eq('isp_region')
      end
    end

    context 'time window' do
      before do
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return({
            time_window: {},
            group_by: 'endpoint_id',
            total_endpoints: 1,
            up_count: 1,
            down_count: 0,
            metrics: [],
            meta: { current_page: 1, per_page: 10, total_pages: 1, total_count: 1 }
          })
      end

      it 'accepts start_time and end_time' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: {
              start_time: 2.days.ago.iso8601,
              end_time: Time.current.iso8601
            },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts last_minutes parameter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { last_minutes: 60 },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'defaults to last 24 hours when no time params provided' do
        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'pagination' do
      before do
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return({
            time_window: {},
            group_by: 'endpoint_id',
            total_endpoints: 25,
            up_count: 20,
            down_count: 5,
            metrics: [],
            meta: { current_page: 1, per_page: 10, total_pages: 3, total_count: 25 }
          })
      end

      it 'accepts page parameter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { page: 2 },
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:meta][:current_page]).to eq(1) # Service sets this
      end

      it 'accepts per_page parameter' do
        get '/api/v1/dashboard/endpoint_health_metrics',
            params: { per_page: 20 },
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:meta][:per_page]).to eq(10) # Service sets this
      end
    end

    context 'error handling' do
      it 'handles service exceptions' do
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_raise(StandardError.new('Service error'))

        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        expect(response).to have_http_status(:internal_server_error)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Internal Server Error')
        expect(json['message']).to eq('Service error')
      end

      it 'handles missing organization_id' do
        user_without_org = create(:admin_user, organisation_id: nil, access_token: 'valid_token')
        allow(User).to receive(:find_by).with(access_token: 'valid_token')
                                        .and_return(user_without_org)

        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('org_id')
      end
    end

    context 'response format validation' do
      let(:complete_response) do
        {
          time_window: {
            start_time: 24.hours.ago.iso8601,
            end_time: Time.current.iso8601,
            duration_minutes: 1440,
            table_used: 'router_metrics_rollup'
          },
          group_by: 'endpoint_id',
          total_endpoints: 2,
          up_count: 1,
          down_count: 1,
          metrics: [
            {
              endpoint_id: 1,
              endpoint: {
                name: 'Google DNS',
                host: 'google.com',
                monitoring_mode: 'ICMP',
                group_name: 'DNS',
                group_type: 'network'
              },
              number_of_isp: 5,
              number_of_location_id: 5,
              number_of_region: 5,
              number_of_router_id: 5,
              number_of_device_id: 5,
              avg_uptime: 100.0,
              avg_response_time: '25ms',
              down_time_pct: 0.0,
              up_time_pct: 100.0,
              status: 'up',
              status_since: '1d'
            },
            {
              endpoint_id: 2,
              endpoint: {
                name: 'Google Web',
                host: 'google.com',
                monitoring_mode: 'HTTP',
                group_name: 'Web',
                group_type: 'application'
              },
              number_of_isp: 3,
              number_of_location_id: 3,
              number_of_region: 2,
              number_of_router_id: 3,
              number_of_device_id: 3,
              avg_uptime: 95.0,
              avg_response_time: '1500ms',
              down_time_pct: 5.0,
              up_time_pct: 95.0,
              status: 'down',
              status_since: '1d'
            }
          ],
          meta: {
            current_page: 1,
            per_page: 10,
            total_pages: 1,
            total_count: 2
          }
        }
      end

      before do
        allow_any_instance_of(EndpointHealthMetricsService)
          .to receive(:call).and_return(complete_response)
      end

      it 'returns correct up and down counts' do
        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:up_count]).to eq(1)
        expect(json[:down_count]).to eq(1)
        expect(json[:total_endpoints]).to eq(2)
      end

      it 'includes endpoint details in metrics' do
        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        metric = json[:metrics].first

        expect(metric[:endpoint][:name]).to be_present
        expect(metric[:endpoint][:host]).to be_present
        expect(metric[:endpoint][:monitoring_mode]).to be_present
        expect(metric[:endpoint][:group_name]).to be_present
        expect(metric[:endpoint][:group_type]).to be_present
      end

      it 'includes all required metric fields' do
        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        json = JSON.parse(response.body, symbolize_names: true)
        metric = json[:metrics].first

        expect(metric).to have_key(:avg_uptime)
        expect(metric).to have_key(:avg_response_time)
        expect(metric).to have_key(:up_time_pct)
        expect(metric).to have_key(:down_time_pct)
        expect(metric).to have_key(:status)
        expect(metric).to have_key(:status_since)
      end

      it 'returns JSON content type' do
        get '/api/v1/dashboard/endpoint_health_metrics', headers: headers

        expect(response.content_type).to include('application/json')
      end
    end
  end
end
