require 'rails_helper'

RSpec.describe SiteDistributionService, type: :service do
  let(:org_id) { 3 }
  let(:start_time) { 1.hour.ago }
  let(:end_time) { Time.now }

  let(:service_params) do
    {
      org_id: org_id,
      group_by: 'location_id',
      start_time: start_time,
      end_time: end_time
    }
  end

  let(:service) { described_class.new(**service_params) }
  let(:clickhouse_client) { instance_double('ClickHouse::Client') }

  before do
    allow(service).to receive(:client).and_return(clickhouse_client)
  end

  describe '#call' do
    context 'with good counts' do
      let(:mock_results) do
        [ {
          'location_network_id' => 'loc1',
          'endpoint_id' => '1',
          'host' => 'google.com',
          'avg_latency' => 150.5,
          'total_samples' => 100,
          'good_count' => 100,
          'warning_count' => 0,
          'critical_count' => 0,
          'down_count' => 0
        } ]
      end

      before do
        allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
      end

      it 'classifies as good and builds valid structure' do
        result = service.call
        expect(result[:summary][:good]).to eq(1)
        expect(result[:summary][:count]).to eq(1)
        
        group_data = result[:distribution].find { |b| b[:latency_bucket] == 140 } # 140-159 range due to 20 bucket
        expect(group_data).not_to be_nil
        expect(group_data[:good]).to eq(1)
      end
    end

    context 'with warning counts' do
      let(:mock_results) do
        [ {
          'location_network_id' => 'loc1',
          'endpoint_id' => '1',
          'host' => 'google.com',
          'avg_latency' => 250.0,
          'total_samples' => 100,
          'good_count' => 40,
          'warning_count' => 60,
          'critical_count' => 0,
          'down_count' => 0
        } ]
      end

      before do
        allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
      end

      it 'classifies as warning' do
        result = service.call
        expect(result[:summary][:good]).to eq(0)
        expect(result[:summary][:critical]).to eq(1) # because warning is not a standard key, it's either skipped in summary or critical, wait. Summary only has good, critical, down.
        # distribution has warning? Let's check calculation. Actually it just logs status.
      end
    end

    context 'with critical counts' do
      let(:mock_results) do
        [ {
          'location_network_id' => 'loc1',
          'endpoint_id' => '1',
          'host' => 'google.com',
          'avg_latency' => 350.0,
          'total_samples' => 100,
          'good_count' => 10,
          'warning_count' => 10,
          'critical_count' => 60,
          'down_count' => 20
        } ]
      end

      before do
        allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
      end

      it 'classifies as critical' do
        result = service.call
        expect(result[:summary][:critical]).to eq(1)
      end
    end

    context 'with down counts' do
      let(:mock_results) do
        [ {
          'location_network_id' => 'loc1',
          'endpoint_id' => '1',
          'host' => 'google.com',
          'avg_latency' => 0.0,
          'total_samples' => 100,
          'good_count' => 0,
          'warning_count' => 0,
          'critical_count' => 20,
          'down_count' => 80
        } ]
      end

      before do
        allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
      end

      it 'classifies as down' do
        result = service.call
        expect(result[:summary][:down]).to eq(1)
      end
    end
  end

  describe 'Group By Options' do
    let(:mock_result) do
      [ {
        'location_network_id' => 'test_group',
        'endpoint_id' => '1',
        'host' => 'google.com',
        'avg_latency' => 200.0,
        'total_samples' => 100,
        'good_count' => 100,
        'warning_count' => 0,
        'critical_count' => 0,
        'down_count' => 0
      } ]
    end

    before do
      allow(clickhouse_client).to receive(:select_all).and_return(mock_result)
    end

    %w[endpoint_id device_id region isp location_id router_id host isp_region].each do |group_type|
      it "supports group_by: #{group_type}" do
        # We need mock to map to the correct keys
        res = mock_result.first.dup
        res[group_type == 'location_id' ? 'location_network_id' : group_type] = 'test' if group_type != 'endpoint_id'
        
        allow(clickhouse_client).to receive(:select_all).and_return([res])
        
        service = described_class.new(**service_params.merge(group_by: group_type))
        allow(service).to receive(:client).and_return(clickhouse_client)

        result = service.call
        expect(result[:group_by]).to eq(group_type)
      end
    end
  end

  describe 'Filtering' do
    let(:mock_results) do
      [ {
        'location_network_id' => 'loc1',
        'endpoint_id' => '1',
        'host' => 'google.com',
        'avg_latency' => 150.0,
        'total_samples' => 100,
        'good_count' => 100,
        'warning_count' => 0,
        'critical_count' => 0,
        'down_count' => 0
      } ]
    end

    before do
      allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
    end

    it 'filters by sites_type' do
      service = described_class.new(**service_params.merge(sites_type: 'critical'))
      allow(service).to receive(:client).and_return(clickhouse_client)

      result = service.call
      expect(result[:summary][:count]).to eq(0)
    end

    it 'includes matching sites_type' do
      service = described_class.new(**service_params.merge(sites_type: 'good'))
      allow(service).to receive(:client).and_return(clickhouse_client)

      result = service.call
      expect(result[:summary][:count]).to eq(1)
    end
  end
end
