require 'rails_helper'

RSpec.describe EndpointLocationStatusService, type: :service do
  let(:org_id) { 1 }
  let(:endpoint_id) { 1 }
  let(:start_time) { 2.hours.ago.utc }
  let(:end_time) { Time.current.utc }

  let(:service_params) do
    {
      org_id: org_id,
      endpoint_id: endpoint_id,
      start_time: start_time,
      end_time: end_time
    }
  end

  let(:service) { described_class.new(service_params) }
  let(:endpoint) { instance_double('EndpointMonitoringEndpoint', id: endpoint_id, name: 'Test', monitoring_mode: 'icmp') }

  before do
    allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([])
    allow(EndpointMonitoringEndpoint).to receive_message_chain(:joins, :where, :first).and_return(endpoint)
  end

  describe '#call' do
    context 'when fetch_location_metrics returns data' do
      let(:mock_metrics) do
        [
          {
            "location_network_id" => 100,
            "region" => 'US-East',
            "isp" => 'AWS',
            "isp_count" => 1,
            "region_count" => 1,
            "router_inventory_count" => 1,
            "device_count" => 1,
            "total_latency" => 1500.0,
            "good_count" => 10,
            "warning_count" => 0,
            "critical_count" => 0,
            "down_count" => 0,
            "sample_count" => 10
          },
          {
            "location_network_id" => 200,
            "region" => 'US-West',
            "isp" => 'GCP',
            "isp_count" => 1,
            "region_count" => 1,
            "router_inventory_count" => 1,
            "device_count" => 1,
            "total_latency" => 5000.0,
            "good_count" => 0,
            "warning_count" => 0,
            "critical_count" => 0,
            "down_count" => 10,
            "sample_count" => 10
          }
        ]
      end

      before do
        allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return(mock_metrics)
      end

      it 'returns locations mapped to proper up and down status' do
        result = service.call

        expect(result[:location_networks].length).to eq(2)
        expect(result[:summary][:good_locations]).to eq(1)
        expect(result[:summary][:down_locations]).to eq(1)

        # Sorts down first usually depending on the code, let's just check by id
        loc_100 = result[:location_networks].find { |l| l[:location_network_id] == 100 }
        loc_200 = result[:location_networks].find { |l| l[:location_network_id] == 200 }

        expect(loc_100[:status]).to eq("good")
        expect(loc_200[:status]).to eq("down")
      end
    end
  end
end
