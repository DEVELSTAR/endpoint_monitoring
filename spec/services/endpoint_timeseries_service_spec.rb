require 'rails_helper'

RSpec.describe EndpointTimeseriesService, type: :service do
  let(:org_id) { 1 }
  let(:endpoint_id) { 1 }
  let(:start_time) { 2.hours.ago.utc }
  let(:end_time) { Time.current.utc }
  let(:bucket_minutes) { 15 }

  let(:service_params) do
    {
      org_id: org_id,
      endpoint_id: endpoint_id,
      start_time: start_time,
      end_time: end_time,
      bucket_minutes: bucket_minutes
    }
  end

  let(:service) { described_class.new(**service_params) }

  let(:endpoint_config) do
    instance_double('EndpointMonitoringEndpoint', id: endpoint_id, host: 'test.com', monitoring_mode: 'HTTP', endpoint_monitoring_group: nil)
  end

  before do
    allow(EndpointMonitoringEndpoint).to receive_message_chain(:includes, :find_by).and_return(endpoint_config)
    allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([])
  end

  describe '#call' do
    context 'when fetch_timeseries_buckets returns data' do
      let(:mock_bucket_data) do
        [
          {
            "time_bucket" => service.send(:truncate_to_bucket, start_time).iso8601,
            "avg_latency_ms" => 150.0,
            "good_count" => 10,
            "warning_count" => 0,
            "critical_count" => 0,
            "down_count" => 0,
            "sample_count" => 10
          }
        ]
      end

      before do
        allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return(mock_bucket_data)
      end

      it 'returns correctly formatted structure' do
        result = service.call

        expect(result[:time_window][:start_time]).to eq(start_time.iso8601)
        expect(result[:endpoint][:host]).to eq('test.com')
        
        # At least one element has good, the rest are no_data
        good_buckets = result[:timeseries].select { |b| b[:status] == "good" }
        no_data_buckets = result[:timeseries].select { |b| b[:status] == "no_data" }
        
        expect(good_buckets.length).to eq(1)
        expect(no_data_buckets.length).to be > 0
      end
    end
  end
end
