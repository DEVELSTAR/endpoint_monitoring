require 'rails_helper'

RSpec.describe EndpointReportsService, type: :service do
  let(:org_id) { 6 }
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

  let(:service) { described_class.new(**service_params) }

  before do
    allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([])
  end

  describe '#calculate_bucket_minutes' do
    it 'returns 120 minutes (2h) for durations <= 24 hours' do
      svc = described_class.new(org_id: 1, start_time: 20.hours.ago, end_time: Time.current)
      expect(svc.send(:calculate_bucket_minutes)).to eq(120)
    end

    it 'returns 1440 minutes (1d) for durations >= 24h but < 30 days' do
      svc = described_class.new(org_id: 1, start_time: 15.days.ago, end_time: Time.current)
      expect(svc.send(:calculate_bucket_minutes)).to eq(1440)
    end

    it 'returns 10080 minutes (1w) for durations >= 30 days' do
      svc = described_class.new(org_id: 1, start_time: 45.days.ago, end_time: Time.current)
      expect(svc.send(:calculate_bucket_minutes)).to eq(10080)
    end
  end

  describe '#format_results' do
    let(:time_bucket) { '2026-04-01 00:00:00' }

    let(:mock_results) do
      [
        {
          'time_bucket' => time_bucket,
          'endpoint_id' => '1',
          'good_count' => 10,
          'warning_count' => 0,
          'critical_count' => 0,
          'down_count' => 0
        },
        {
          'time_bucket' => time_bucket,
          'endpoint_id' => '2',
          'good_count' => 4,
          'warning_count' => 6, # 60% warning -> mapped to warning status, then to good
          'critical_count' => 0,
          'down_count' => 0
        },
        {
          'time_bucket' => time_bucket,
          'endpoint_id' => '3',
          'good_count' => 0,
          'warning_count' => 0,
          'critical_count' => 10, # 100% critical -> critical status
          'down_count' => 0
        },
        {
          'time_bucket' => time_bucket,
          'endpoint_id' => '4',
          'good_count' => 0,
          'warning_count' => 0,
          'critical_count' => 0,
          'down_count' => 10 # 100% down -> down status
        }
      ]
    end

    before do
      allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return(mock_results)
    end

    it 'maps warning onto good correctly and distributes status percentages' do
      result = service.call

      expect(result[:summary]).to include(
        good: 50.0,     # 1 good + 1 warning -> 2/4
        critical: 25.0, # 1 critical -> 1/4
        down: 25.0      # 1 down -> 1/4
      )

      expect(result[:metrics].first).to include(
        time: Time.parse(time_bucket).utc.iso8601,
        good: 50.0,
        critical: 25.0,
        down: 25.0
      )
    end

    it 'handles empty results without failing' do
      allow(Clickhouse::Base).to receive_message_chain(:connection, :select_all).and_return([]) 

      result = service.call

      expect(result[:summary]).to include(good: 0.0, critical: 0.0, down: 0.0)
      expect(result[:metrics]).to be_empty
    end
  end
end
