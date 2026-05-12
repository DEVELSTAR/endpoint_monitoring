require 'rails_helper'

RSpec.describe EndpointLocationsService, type: :service do
  let(:org_id) { 'test_org_id' }
  let(:endpoint_id) { '123' }
  let(:start_time) { Time.parse('2023-01-01T10:00:00Z') }
  let(:end_time) { Time.parse('2023-01-01T11:00:00Z') }
  let(:client_double) { instance_double('ClickHouse::Client') }

  before do
    allow(Clickhouse::Base).to receive(:connection).and_return(client_double)
  end

  describe '#fetch_locations_from_clickhouse' do
    let(:service) { described_class.new(org_id: org_id, endpoint_id: endpoint_id, start_time: start_time, end_time: end_time) }

    context 'with location data' do
      let(:clickhouse_response) do
        { "location_ids" => ["100", "200"] }
      end

      before do
        allow(client_double).to receive(:select_one).and_return(clickhouse_response)
        relation_mock = double('ActiveRecord::Relation')
        allow(LocationNetwork).to receive(:where).and_return(relation_mock)
        allow(relation_mock).to receive(:pluck).and_return([[100, 'Delhi Office'], [200, 'Mumbai Office']])
      end

      it 'returns formatted location data' do
        result = service.send(:fetch_locations_from_clickhouse)

        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
        expect(result.first).to eq({ id: 100, name: 'Delhi Office' })
        expect(result.second).to eq({ id: 200, name: 'Mumbai Office' })
      end
    end
  end

  describe '#fetch_devices_from_clickhouse' do
    let(:service) { described_class.new(org_id: org_id, endpoint_id: endpoint_id, start_time: start_time, end_time: end_time, group_by: 'devices') }

    context 'with device data' do
      let(:clickhouse_response) do
        [
          { "id" => "1001", "mac_id" => "AA:BB:CC:DD:EE:01" },
          { "id" => "1002", "mac_id" => "AA:BB:CC:DD:EE:02" }
        ]
      end

      before do
        allow(client_double).to receive(:select_all).and_return(clickhouse_response)
      end

      it 'returns formatted device data' do
        result = service.send(:fetch_devices_from_clickhouse)

        expect(result.size).to eq(2)
        expect(result.first).to eq({ id: 1001, mac_id: 'AA:BB:CC:DD:EE:01' })
      end
    end
  end
end
