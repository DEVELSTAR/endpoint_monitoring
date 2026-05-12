require 'rails_helper'

RSpec.describe GroupedTimeseriesService, type: :service do
  let(:org_id) { 1 }
  let(:start_time) { 2.hours.ago.utc }
  let(:end_time) { Time.current.utc }
  let(:bucket_minutes) { 15 }

  let(:service_params) do
    {
      org_id: org_id,
      start_time: start_time,
      end_time: end_time,
      bucket_minutes: bucket_minutes
    }
  end

  let(:service) { described_class.new(**service_params) }

  before do
    allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([])
  end

  describe '#call' do
    context 'when fetch_all_data returns data' do
      let(:mock_data) do
        [
          {
            "query_type" => "timeseries",
            "time_bucket" => start_time.iso8601,
            "avg_latency_ms" => 150.0,
            "sample_count" => 10,
            "good_count" => 10,
            "warning_count" => 0,
            "critical_count" => 0,
            "down_count" => 0
          },
          {
            "query_type" => "summary",
            "time_bucket" => '1970-01-01T00:00:00Z',
            "avg_latency_ms" => 0.0,
            "sample_count" => 0,
            "good_count" => 0,
            "warning_count" => 0,
            "critical_count" => 0,
            "down_count" => 0,
            "total_samples" => 10,
            "total_endpoints" => 1,
            "total_devices" => 2,
            "total_hosts" => 1,
            "total_regions" => 1,
            "total_isps" => 1,
            "total_location_networks" => 1,
            "total_router_inventories" => 1
          }
        ]
      end

      before do
        allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return(mock_data)
      end

      it 'returns correctly formatted structure with status counts' do
        result = service.call

        expect(result[:timeseries].length).to eq(1)
        expect(result[:timeseries].first[:status]).to eq("good")

        expect(result[:summary][:good_points]).to eq(1)
        expect(result[:summary][:total_data_points]).to eq(1)
        expect(result[:summary][:endpoint_count]).to eq(1)
        expect(result[:summary][:device_count]).to eq(2)
      end
    end
  end
end
