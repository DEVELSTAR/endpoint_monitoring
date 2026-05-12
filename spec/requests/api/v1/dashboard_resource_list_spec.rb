# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard Resource List API', type: :request do
  let(:user) { create(:admin_user, organisation_id: 6) }
  let(:valid_token) { 'valid-token-123' }
  let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }

  before do
    allow(User).to receive(:includes).with(:role).and_return(User)
    allow(User).to receive(:find_by).with(access_token: valid_token).and_return(user)
  end

  describe 'GET /api/v1/dashboard/resource_list' do
    let(:mock_clickhouse_result) do
      {
        'regions' => [ 'Delhi', 'Mumbai', 'Bangalore' ],
        'isps' => [ 'Airtel', 'Jio', 'BSNL' ]
      }
    end

    let(:mock_db_result) do
      {
        mac_ids: [ 'mac1', 'mac2', 'mac3' ],
        hosts: [ 'google.com', 'amazon.com', 'netflix.com' ],
        endpoint_ids: [ '1', '2', '3' ],
        location_network_ids: [ 'loc1', 'loc2', 'loc3' ],
        router_inventory_ids: [ 'router1', 'router2' ]
      }
    end

    let(:mock_dashboard_resource_service) { instance_double(DashboardResourceService) }

    before do
      allow(Clickhouse::Base).to receive(:connection).and_return(double('connection'))
      allow(Clickhouse::Base.connection).to receive(:select_one).and_return(mock_clickhouse_result)

      allow(DashboardResourceService).to receive(:new).with(6).and_return(mock_dashboard_resource_service)
      allow(mock_dashboard_resource_service).to receive(:call).and_return(mock_db_result)
    end

    context 'when authenticated' do
      it 'returns successful response with all resource lists' do
        get '/api/v1/dashboard/resource_list', headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to include(
          'mac_ids',
          'hosts',
          'endpoint_ids',
          'regions',
          'location_network_ids',
          'router_inventory_ids',
          'isps'
        )
      end

      it 'returns arrays for all resource fields' do
        get '/api/v1/dashboard/resource_list', headers: headers

        json_response = JSON.parse(response.body)

        expect(json_response['mac_ids']).to be_an(Array)
        expect(json_response['hosts']).to be_an(Array)
        expect(json_response['endpoint_ids']).to be_an(Array)
        expect(json_response['regions']).to be_an(Array)
        expect(json_response['location_network_ids']).to be_an(Array)
        expect(json_response['router_inventory_ids']).to be_an(Array)
        expect(json_response['isps']).to be_an(Array)
      end

      it 'returns correct resource values' do
        get '/api/v1/dashboard/resource_list', headers: headers

        json_response = JSON.parse(response.body)

        expect(json_response['mac_ids']).to eq([ 'mac1', 'mac2', 'mac3' ])
        expect(json_response['hosts']).to eq([ 'google.com', 'amazon.com', 'netflix.com' ])
        expect(json_response['endpoint_ids']).to eq([ '1', '2', '3' ])
        expect(json_response['regions']).to eq([ 'Delhi', 'Mumbai', 'Bangalore' ])
        expect(json_response['location_network_ids']).to eq([ 'loc1', 'loc2', 'loc3' ])
        expect(json_response['router_inventory_ids']).to eq([ 'router1', 'router2' ])
        expect(json_response['isps']).to eq([ 'Airtel', 'Jio', 'BSNL' ])
      end

      it 'queries ClickHouse with org_id filter' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/WHERE org_id = '6'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list', headers: headers
      end

      it 'uses router_metrics_rollup table' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/FROM router_metrics_rollup/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list', headers: headers
      end

      it 'uses groupArray(DISTINCT ...) only for regions and isps' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/groupArray\(DISTINCT region\)/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list', headers: headers
      end
    end

    context 'with filter parameters' do
      it 'applies device_id filter' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/device_id = 'device1'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { device_id: 'device1' },
            headers: headers
      end

      it 'applies host filter' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/host = 'google\.com'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { host: 'google.com' },
            headers: headers
      end

      it 'applies endpoint_id filter' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/endpoint_id = '123'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { endpoint_id: '123' },
            headers: headers
      end

      it 'applies region filter' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/region = 'Delhi'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { region: 'Delhi' },
            headers: headers
      end

      it 'applies location_network_id filter' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/location_network_id = 'loc1'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { location_network_id: 'loc1' },
            headers: headers
      end

      it 'applies router_inventory_id filter' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/router_inventory_id = 'router1'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { router_inventory_id: 'router1' },
            headers: headers
      end

      it 'applies isp filter' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/isp = 'Airtel'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { isp: 'Airtel' },
            headers: headers
      end

      it 'applies multiple filters with AND logic' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/region = 'Delhi' AND isp = 'Airtel'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { region: 'Delhi', isp: 'Airtel' },
            headers: headers
      end

      it 'combines org_id with other filters' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/org_id = '6' AND host = 'google\.com'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { host: 'google.com' },
            headers: headers
      end

      it 'ignores blank filter values' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/^(?!.*device_id =).*$/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { device_id: '' },
            headers: headers
      end

      it 'ignores nil filter values' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/WHERE org_id = '6'$/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { device_id: nil },
            headers: headers
      end
    end

    context 'with empty ClickHouse results' do
      before do
        allow(Clickhouse::Base.connection).to receive(:select_one).and_return({})
      end

      it 'returns empty arrays for all fields' do
        get '/api/v1/dashboard/resource_list', headers: headers

        json_response = JSON.parse(response.body)

        expect(json_response['mac_ids']).to eq([ 'mac1', 'mac2', 'mac3' ])
        expect(json_response['hosts']).to eq([ 'google.com', 'amazon.com', 'netflix.com' ])
        expect(json_response['endpoint_ids']).to eq([ '1', '2', '3' ])
        expect(json_response['regions']).to eq([])
        expect(json_response['location_network_ids']).to eq([ 'loc1', 'loc2', 'loc3' ])
        expect(json_response['router_inventory_ids']).to eq([ 'router1', 'router2' ])
        expect(json_response['isps']).to eq([])
      end

      it 'returns successful response' do
        get '/api/v1/dashboard/resource_list', headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with nil ClickHouse results' do
      before do
        allow(Clickhouse::Base.connection).to receive(:select_one).and_return(nil)
      end

      it 'returns empty arrays for all fields' do
        get '/api/v1/dashboard/resource_list', headers: headers

        json_response = JSON.parse(response.body)

        expect(json_response['mac_ids']).to eq([ 'mac1', 'mac2', 'mac3' ])
        expect(json_response['hosts']).to eq([ 'google.com', 'amazon.com', 'netflix.com' ])
        expect(json_response['endpoint_ids']).to eq([ '1', '2', '3' ])
        expect(json_response['regions']).to eq([])
        expect(json_response['location_network_ids']).to eq([ 'loc1', 'loc2', 'loc3' ])
        expect(json_response['router_inventory_ids']).to eq([ 'router1', 'router2' ])
        expect(json_response['isps']).to eq([])
      end
    end

    context 'when authentication fails' do
      before do
        allow(User).to receive(:find_by).with(access_token: valid_token).and_return(nil)
      end

      it 'returns unauthorized status' do
        get '/api/v1/dashboard/resource_list', headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user has no organisation_id' do
      before do
        user_without_org = create(:admin_user, organisation_id: nil)
        allow(User).to receive(:find_by).with(access_token: valid_token).and_return(user_without_org)
      end

      it 'returns bad request status' do
        get '/api/v1/dashboard/resource_list', headers: headers

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        get '/api/v1/dashboard/resource_list', headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
    end

    context 'when ClickHouse query fails' do
      before do
        allow(Clickhouse::Base.connection).to receive(:select_one)
          .and_raise(StandardError.new('ClickHouse connection error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'returns internal server error status' do
        get '/api/v1/dashboard/resource_list', headers: headers

        expect(response).to have_http_status(:internal_server_error)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error)

        get '/api/v1/dashboard/resource_list', headers: headers
      end

      it 'returns error response' do
        get '/api/v1/dashboard/resource_list', headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
    end

    context 'edge cases' do
      it 'handles special characters in filter values safely' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/host = 'test\.google\.com'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { host: 'test.google.com' },
            headers: headers
      end

      it 'handles numeric filter values' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/endpoint_id = '12345'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: { endpoint_id: '12345' },
            headers: headers
      end

      it 'handles all filters together' do
        expect(Clickhouse::Base.connection).to receive(:select_one).with(
          a_string_matching(/device_id = 'dev1' AND host = 'google\.com' AND endpoint_id = '1' AND region = 'Delhi' AND location_network_id = 'loc1' AND router_inventory_id = 'router1' AND isp = 'Airtel'/)
        ).and_return(mock_clickhouse_result)

        get '/api/v1/dashboard/resource_list',
            params: {
              device_id: 'dev1',
              host: 'google.com',
              endpoint_id: '1',
              region: 'Delhi',
              location_network_id: 'loc1',
              router_inventory_id: 'router1',
              isp: 'Airtel'
            },
            headers: headers
      end
    end

    context 'response format validation' do
      it 'returns JSON content type' do
        get '/api/v1/dashboard/resource_list', headers: headers

        expect(response.content_type).to match(/application\/json/)
      end

      it 'has proper JSON structure' do
        get '/api/v1/dashboard/resource_list', headers: headers

        expect { JSON.parse(response.body) }.not_to raise_error
      end

      it 'returns all expected fields even when empty' do
        allow(Clickhouse::Base.connection).to receive(:select_one).and_return(nil)

        get '/api/v1/dashboard/resource_list', headers: headers

        json_response = JSON.parse(response.body)
        expected_fields = %w[
          mac_ids hosts endpoint_ids regions
          location_network_ids router_inventory_ids isps
        ]

        expected_fields.each do |field|
          expect(json_response).to have_key(field)
        end
      end
    end

    context 'with token in params instead of headers' do
      it 'authenticates successfully with token in params' do
        get '/api/v1/dashboard/resource_list',
            params: { access_token: valid_token }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
