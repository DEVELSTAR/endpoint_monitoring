require 'rails_helper'

RSpec.describe LatencyAnalysisService, type: :service do
  let(:org_id) { 3 }
  let(:start_time) { 1.hour.ago }
  let(:end_time) { Time.now }

  let(:service_params) do
    {
      org_id: org_id,
      group_by: 'endpoint_id',
      start_time: start_time,
      end_time: end_time
    }
  end

  let(:service) { described_class.new(**service_params) }
  let(:clickhouse_client) { instance_double('ClickHouse::Client') }
  let(:mock_group) { instance_double('EndpointMonitoringGroup', name: 'Test Group') }

  let(:endpoint) do
    instance_double(
      'EndpointMonitoringEndpoint',
      id: 1,
      host: 'google.com',
      monitoring_mode: 'ICMP',
      latency_warning: 200,
      latency_critical: 300,
      response_time: nil,
      acceptable_response_codes: nil,
      endpoint_monitoring_group: mock_group
    )
  end

  before do
    allow(service).to receive(:client).and_return(clickhouse_client)
  end

  describe '#call' do
    context 'with good counts' do
      let(:mock_results) do
        [ {
          'group_key' => '1',
          'endpoint_id' => '1',
          'avg_latency_ms' => 150.5,
          'sample_count' => 100,
          'good_count' => 100,
          'warning_count' => 0,
          'critical_count' => 0,
          'down_count' => 0,
          'last_status' => '1'
        } ]
      end

      before do
        allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
        allow(EndpointMonitoringEndpoint).to receive(:includes).with(:endpoint_monitoring_group).and_return(EndpointMonitoringEndpoint)
        allow(EndpointMonitoringEndpoint).to receive(:where).and_return([ endpoint ])
      end

      it 'classifies as good' do
        result = service.call
        expect(result[:data][0][:status]).to eq(:good)
      end
    end

    context 'with warning counts' do
      let(:mock_results) do
        [ {
          'group_key' => '1',
          'endpoint_id' => '1',
          'avg_latency_ms' => 250.0,
          'sample_count' => 100,
          'good_count' => 40,
          'warning_count' => 60,
          'critical_count' => 0,
          'down_count' => 0,
          'last_status' => '2'
        } ]
      end

      before do
        allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
        allow(EndpointMonitoringEndpoint).to receive(:includes).with(:endpoint_monitoring_group).and_return(EndpointMonitoringEndpoint)
        allow(EndpointMonitoringEndpoint).to receive(:where).and_return([ endpoint ])
      end

      it 'classifies as warning' do
        result = service.call
        expect(result[:data][0][:status]).to eq(:warning)
      end
    end

    context 'with critical counts' do
      let(:mock_results) do
        [ {
          'group_key' => '1',
          'endpoint_id' => '1',
          'avg_latency_ms' => 350.0,
          'sample_count' => 100,
          'good_count' => 10,
          'warning_count' => 10,
          'critical_count' => 60,
          'down_count' => 20,
          'last_status' => '3'
        } ]
      end

      before do
        allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
        allow(EndpointMonitoringEndpoint).to receive(:includes).with(:endpoint_monitoring_group).and_return(EndpointMonitoringEndpoint)
        allow(EndpointMonitoringEndpoint).to receive(:where).and_return([ endpoint ])
      end

      it 'classifies as critical' do
        result = service.call
        expect(result[:data][0][:status]).to eq(:critical)
      end
    end

    context 'with down counts' do
      let(:mock_results) do
        [ {
          'group_key' => '1',
          'endpoint_id' => '1',
          'avg_latency_ms' => 0.0,
          'sample_count' => 100,
          'good_count' => 0,
          'warning_count' => 0,
          'critical_count' => 20,
          'down_count' => 80,
          'last_status' => '4'
        } ]
      end

      before do
        allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
        allow(EndpointMonitoringEndpoint).to receive(:includes).with(:endpoint_monitoring_group).and_return(EndpointMonitoringEndpoint)
        allow(EndpointMonitoringEndpoint).to receive(:where).and_return([ endpoint ])
      end

      it 'classifies as down' do
        result = service.call
        expect(result[:data][0][:status]).to eq(:down)
      end
    end
  end

  describe 'Group By Options' do
    let(:mock_result) do
      [ {
        'group_key' => 'test_group',
        'endpoint_id' => '1',
        'avg_latency_ms' => 200.0,
        'sample_count' => 100,
        'good_count' => 100,
        'warning_count' => 0,
        'critical_count' => 0,
        'down_count' => 0,
        'last_status' => '1'
      } ]
    end

    before do
      allow(clickhouse_client).to receive(:select_all).and_return(mock_result)
      allow(EndpointMonitoringEndpoint).to receive(:includes).with(:endpoint_monitoring_group).and_return(EndpointMonitoringEndpoint)
      allow(EndpointMonitoringEndpoint).to receive(:where).and_return([ endpoint ])
    end

    %w[endpoint_id device_id region isp location_id router_id host isp_region].each do |group_type|
      it "supports group_by: #{group_type}" do
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
        'group_key' => '1',
        'endpoint_id' => '1',
        'avg_latency_ms' => 150.0,
        'sample_count' => 100,
        'good_count' => 100,
        'warning_count' => 0,
        'critical_count' => 0,
        'down_count' => 0,
        'last_status' => '1'
      } ]
    end

    before do
      allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
      allow(EndpointMonitoringEndpoint).to receive(:includes).with(:endpoint_monitoring_group).and_return(EndpointMonitoringEndpoint)
      allow(EndpointMonitoringEndpoint).to receive(:where).and_return([ endpoint ])
    end

    it 'filters by sites_type' do
      service = described_class.new(**service_params.merge(sites_type: 'critical'))
      allow(service).to receive(:client).and_return(clickhouse_client)

      result = service.call
      expect(result[:data]).to be_empty
    end

    it 'includes matching sites_type' do
      service = described_class.new(**service_params.merge(sites_type: 'good'))
      allow(service).to receive(:client).and_return(clickhouse_client)

      result = service.call
      expect(result[:data].size).to eq(1)
    end
  end

  describe 'Response Structure' do
    let(:mock_results) do
      [ {
        'group_key' => '1',
        'endpoint_id' => '1',
        'avg_latency_ms' => 150.0,
        'sample_count' => 100,
        'good_count' => 100,
        'warning_count' => 0,
        'critical_count' => 0,
        'down_count' => 0,
        'last_status' => '1'
      } ]
    end

    before do
      allow(clickhouse_client).to receive(:select_all).and_return(mock_results)
      allow(EndpointMonitoringEndpoint).to receive(:includes).with(:endpoint_monitoring_group).and_return(EndpointMonitoringEndpoint)
      allow(EndpointMonitoringEndpoint).to receive(:where).and_return([ endpoint ])
    end

    it 'returns complete response structure' do
      result = service.call

      expect(result).to have_key(:time_window)
      expect(result).to have_key(:group_by)
      expect(result).to have_key(:response_efficiency)
      expect(result).to have_key(:data)
    end

    it 'includes all data fields' do
      result = service.call
      data_row = result[:data][0]

      expect(data_row).to have_key(:endpoint_id)
      expect(data_row).to have_key(:avg_latency_ms)
      expect(data_row).to have_key(:sample_count)
      expect(data_row).to have_key(:status)
    end

    it 'calculates efficiency correctly' do
      result = service.call

      expect(result[:response_efficiency][:good]).to eq(100.0)
      expect(result[:response_efficiency][:warning]).to eq(0.0)
      expect(result[:response_efficiency][:critical]).to eq(0.0)
      expect(result[:response_efficiency][:down]).to eq(0.0)
      expect(result[:response_efficiency][:total_count]).to eq(1)
    end
  end

  describe 'comma-separated array support' do
    let(:service_with_arrays) do
      described_class.new(
        org_id: org_id,
        group_by: 'endpoint_id',
        start_time: start_time,
        end_time: end_time,
        host: 'google,youtube',
        isp: 'airtel,jio',
        endpoint_id: '1,2'
      )
    end

    it 'handles comma-separated host values with ILIKE OR conditions' do
      filters = service_with_arrays.send(:build_sql_filters)
      host_filter = filters.find { |f| f.include?('host') }
      expect(host_filter).to eq("(host ILIKE '%google%' OR host ILIKE '%youtube%')")
    end

    it 'handles comma-separated isp values with ILIKE OR conditions' do
      filters = service_with_arrays.send(:build_sql_filters)
      isp_filter = filters.find { |f| f.include?('isp') }
      expect(isp_filter).to eq("(isp ILIKE '%airtel%' OR isp ILIKE '%jio%')")
    end

    it 'handles comma-separated endpoint_id values with IN clause' do
      filters = service_with_arrays.send(:build_sql_filters)
      endpoint_filter = filters.find { |f| f.include?('endpoint_id') }
      expect(endpoint_filter).to eq("endpoint_id IN ('1','2')")
    end
  end
end
