require 'rails_helper'

RSpec.describe LocationEndpointsService, type: :service do
  let(:org_id) { 1 }
  let(:start_time) { 2.hours.ago.utc }
  let(:end_time) { Time.current.utc }

  let(:service_params) do
    {
      org_id: org_id,
      start_time: start_time,
      end_time: end_time,
      group_by: 'locations'
    }
  end

  let(:service) { described_class.new(**service_params) }

  before do
    allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([])
  end

  describe '#call' do
    context 'when fetch_from_rollup returns data' do
      let(:mock_metrics) do
        [
          {
            "endpoint_id" => '1',
            "location_network_id" => '100',
            "avg_latency_ms" => 150.0,
            "good_count" => 10,
            "warning_count" => 0,
            "critical_count" => 0,
            "down_count" => 0,
            "sample_count" => 10
          },
          {
            "endpoint_id" => '2',
            "location_network_id" => '100',
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
        allow(LocationNetwork).to receive(:where).and_return(LocationNetwork.none)
        # Mock pluck directly on relation
        relation_mock = double('ActiveRecord::Relation')
        allow(LocationNetwork).to receive(:where).and_return(relation_mock)
        allow(relation_mock).to receive(:pluck).and_return([[100, 'Test Location']])
      end

      it 'counts endpoints by status correctly' do
        result = service.call
        
        expect(result[:data].length).to eq(1)
        location_data = result[:data].first
        expect(location_data[:location]).to eq('100')
        expect(location_data[:count]).to eq(2)
        expect(location_data[:good]).to eq(1)
        expect(location_data[:down]).to eq(1)
      end
    end
  end
end
