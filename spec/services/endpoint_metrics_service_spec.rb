require 'rails_helper'

RSpec.describe EndpointMetricsService, type: :service do
  let(:org_id) { 1 }
  let(:endpoint_id) { 1 }
  let(:start_time) { 2.hours.ago.utc }
  let(:end_time) { Time.current.utc }

  let(:service_params) do
    {
      org_id: org_id,
      endpoint_id: endpoint_id,
      start_time: start_time,
      end_time: end_time,
      group_by: 'endpoint_id'
    }
  end

  let(:service) { described_class.new(**service_params) }
  let(:endpoint) { instance_double('EndpointMonitoringEndpoint', id: endpoint_id, name: 'Test', host: 'test.com', monitoring_mode: 'icmp') }

  before do
    allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([])
    allow(EndpointMonitoringEndpoint).to receive(:find_by).with(id: endpoint_id).and_return(endpoint)
  end

  describe '#call' do
    context 'when getting single endpoint metrics' do
      let(:mock_metrics) do
        [
          {
            "ts" => start_time.iso8601,
            "latency_ms" => 150.0,
            "region" => 'US-East',
            "location_network_id" => 100,
            "router_inventory_id" => 50,
            "isp" => 'AWS',
            "device_id" => 'device-1',
            "status" => 1, # good -> up
            "http_status" => 200
          },
          {
            "ts" => (start_time + 1.minute).iso8601,
            "latency_ms" => 500.0,
            "region" => 'US-East',
            "location_network_id" => 100,
            "router_inventory_id" => 50,
            "isp" => 'AWS',
            "device_id" => 'device-1',
            "status" => 4, # down -> down
            "http_status" => 500
          }
        ]
      end

      before do
        allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([{"total" => 2}], mock_metrics)
      end

      it 'maps status based on status count column mapping correctly' do
        result = service.call
        
        expect(result[:metrics].length).to eq(2)
        expect(result[:metrics][0][:status]).to eq("good")
        expect(result[:metrics][1][:status]).to eq("down")
        
        # summary calculates uptime by filtering out down points
        expect(result[:summary][:uptime_pct]).to eq(50.0)
      end
    end
  end
end
