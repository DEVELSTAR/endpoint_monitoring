require 'rails_helper'

RSpec.describe EndpointHealthMetricsService, type: :service do
  let(:org_id) { 1 }
  let(:start_time) { 2.hours.ago.utc }
  let(:end_time) { Time.current.utc }

  let(:service_params) do
    {
      org_id: org_id,
      start_time: start_time,
      end_time: end_time,
      group_by: 'endpoint_id'
    }
  end

  let(:service) { described_class.new(service_params) }

  before do
    allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([])
  end

  describe '#call' do
    context 'when fetch_aggregated_metrics returns data' do
      let(:mock_metrics) do
        [
          {
            "group_key" => '1',
            "first_endpoint_id" => '1',
            "endpoint_count" => 1,
            "device_count" => 2,
            "location_count" => 1,
            "region_count" => 1,
            "isp_count" => 1,
            "router_count" => 1,
            "avg_latency_ms" => 150.0,
            "good_count" => 10,
            "warning_count" => 0,
            "critical_count" => 0,
            "down_count" => 0,
            "sample_count" => 10
          },
          {
            "group_key" => '2',
            "first_endpoint_id" => '2',
            "endpoint_count" => 1,
            "device_count" => 1,
            "location_count" => 1,
            "region_count" => 1,
            "isp_count" => 1,
            "router_count" => 1,
            "avg_latency_ms" => 250.0,
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

      it 'counts endpoints by status correctly and returns summary' do
        result = service.call

        expect(result[:metrics].length).to eq(2)
        expect(result[:summary][:good]).to eq(1)
        expect(result[:summary][:down]).to eq(1)

        first = result[:metrics].find { |m| m[:endpoint_id] == '1' }
        second = result[:metrics].find { |m| m[:endpoint_id] == '2' }

        expect(first[:status]).to eq("good")
        expect(second[:status]).to eq("down")
      end
    end
  end
end
