require 'rails_helper'

RSpec.describe UplinkTimeseriesService, type: :service do
  let(:org_id) { "test-org-123" }
  let(:device_id) { "device-001" }
  let(:uplink_id) { "uplink-fiber-01" }
  let(:uplink_type) { "fiber" }
  let(:start_time) { 2.hours.ago }
  let(:end_time) { Time.current }
  let(:bucket_minutes) { 15 }

  let(:service) do
    described_class.new(
      org_id: org_id,
      device_id: device_id,
      uplink_id: uplink_id,
      uplink_type: uplink_type,
      start_time: start_time,
      end_time: end_time,
      bucket_minutes: bucket_minutes
    )
  end

  let(:mock_client) { double('ClickHouse::Client') }
  let(:mock_clickhouse_data) do
    [
      {
        'bucket_time' => 1.hour.ago,
        'uplink_id' => 'uplink-fiber-01',
        'uplink_type' => 'fiber',
        'avg_latency_ms' => 25.5,
        'avg_loss_pct' => 1.2,
        'sample_count' => 100
      },
      {
        'bucket_time' => 30.minutes.ago,
        'uplink_id' => 'uplink-fiber-01',
        'uplink_type' => 'fiber',
        'avg_latency_ms' => 30.0,
        'avg_loss_pct' => 2.1,
        'sample_count' => 95
      },
      {
        'bucket_time' => 1.hour.ago,
        'uplink_id' => 'uplink-4g-01',
        'uplink_type' => '4g',
        'avg_latency_ms' => 45.8,
        'avg_loss_pct' => 3.5,
        'sample_count' => 80
      }
    ]
  end

  before do
    allow_any_instance_of(described_class).to receive(:client).and_return(mock_client)
    allow(mock_client).to receive(:select_all).and_return(mock_clickhouse_data)
  end

  describe '#initialize' do
    context 'with required parameters only' do
      let(:minimal_service) do
        described_class.new(
          org_id: org_id,
          device_id: device_id,
          start_time: start_time,
          end_time: end_time
        )
      end

      it 'initializes with required parameters' do
        expect(minimal_service.instance_variable_get(:@org_id)).to eq(org_id)
        expect(minimal_service.instance_variable_get(:@device_id)).to eq(device_id)
        expect(minimal_service.instance_variable_get(:@start_time)).to eq(start_time)
        expect(minimal_service.instance_variable_get(:@end_time)).to eq(end_time)
      end

      it 'defaults bucket_minutes to 1' do
        expect(minimal_service.instance_variable_get(:@bucket_minutes)).to eq(1)
      end

      it 'sets optional parameters to nil' do
        expect(minimal_service.instance_variable_get(:@uplink_id)).to be_nil
        expect(minimal_service.instance_variable_get(:@uplink_type)).to be_nil
      end
    end

    context 'with all parameters' do
      it 'initializes with all parameters' do
        expect(service.instance_variable_get(:@org_id)).to eq(org_id)
        expect(service.instance_variable_get(:@device_id)).to eq(device_id)
        expect(service.instance_variable_get(:@uplink_id)).to eq(uplink_id)
        expect(service.instance_variable_get(:@uplink_type)).to eq(uplink_type)
        expect(service.instance_variable_get(:@bucket_minutes)).to eq(bucket_minutes)
      end
    end

    context 'with ignored dashboard filter parameters' do
      let(:service_with_filters) do
        described_class.new(
          org_id: org_id,
          device_id: device_id,
          start_time: start_time,
          end_time: end_time,
          host: "google.com",
          endpoint_id: "endpoint-1",
          isp: "Airtel",
          region: "Delhi",
          location_id: "loc-1",
          router_id: "router-1",
          sites_type: "fast"
        )
      end

      it 'accepts dashboard filter parameters without error' do
        expect { service_with_filters }.not_to raise_error
      end

      it 'initializes correctly ignoring extra filters' do
        expect(service_with_filters.instance_variable_get(:@org_id)).to eq(org_id)
        expect(service_with_filters.instance_variable_get(:@device_id)).to eq(device_id)
      end
    end

    context 'with string bucket_minutes' do
      let(:service_string_bucket) do
        described_class.new(
          org_id: org_id,
          device_id: device_id,
          start_time: start_time,
          end_time: end_time,
          bucket_minutes: "5"
        )
      end

      it 'converts string bucket_minutes to integer' do
        expect(service_string_bucket.instance_variable_get(:@bucket_minutes)).to eq(5)
      end
    end
  end

  describe '#call' do
    it 'returns the expected response structure' do
      result = service.call

      expect(result).to have_key(:time_window)
      expect(result).to have_key(:latency)
      expect(result).to have_key(:loss)
    end

    it 'includes correct time window information' do
      result = service.call
      time_window = result[:time_window]

      expect(time_window[:start_time]).to eq(start_time)
      expect(time_window[:end_time]).to eq(end_time)
      expect(time_window[:bucket_minutes]).to eq(bucket_minutes)
    end

    it 'groups timeseries data by uplink_id' do
      result = service.call

      expect(result[:latency]).to be_an(Array)
      expect(result[:loss]).to be_an(Array)

      latency_uplinks = result[:latency].map { |u| u[:uplink_id] }
      expect(latency_uplinks).to include('uplink-fiber-01', 'uplink-4g-01')
    end

    it 'includes timeseries data with correct latency structure' do
      result = service.call
      first_uplink = result[:latency].find { |u| u[:uplink_id] == 'uplink-fiber-01' }

      expect(first_uplink).to have_key(:uplink_id)
      expect(first_uplink).to have_key(:uplink_type)
      expect(first_uplink).to have_key(:timeseries)
      expect(first_uplink[:uplink_type]).to eq('fiber')
      expect(first_uplink[:timeseries]).to be_an(Array)

      first_point = first_uplink[:timeseries].first
      expect(first_point).to have_key(:timestamp)
      expect(first_point).to have_key(:epoch_ts)
      expect(first_point).to have_key(:time_ago)
      expect(first_point).to have_key(:avg_latency_ms)
      expect(first_point).to have_key(:sample_count)
    end

    it 'includes timeseries data with correct loss structure' do
      result = service.call
      first_uplink = result[:loss].find { |u| u[:uplink_id] == 'uplink-fiber-01' }

      expect(first_uplink).to have_key(:uplink_id)
      expect(first_uplink).to have_key(:uplink_type)
      expect(first_uplink).to have_key(:timeseries)

      first_point = first_uplink[:timeseries].first
      expect(first_point).to have_key(:avg_loss_pct)
      expect(first_point).to have_key(:sample_count)
    end

    it 'sorts timeseries by timestamp' do
      result = service.call
      first_uplink = result[:latency].find { |u| u[:uplink_id] == 'uplink-fiber-01' }
      timeseries = first_uplink[:timeseries]

      timestamps = timeseries.map { |t| t[:timestamp] }
      expect(timestamps).to eq(timestamps.sort)
    end

    it 'includes epoch_ts as integer' do
      result = service.call
      first_uplink = result[:latency].first
      first_point = first_uplink[:timeseries].first

      expect(first_point[:epoch_ts]).to be_a(Integer)
      expect(first_point[:epoch_ts]).to be > 0
    end
  end

  describe '#select_table' do
    it 'uses raw table for <= 2 hours' do
      service_2h = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 2.hours.ago,
        end_time: Time.current
      )
      expect(service_2h.send(:select_table)).to eq('internet_quality_raw')
    end

    it 'uses raw table for <= 2 days' do
      service_1day = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 1.day.ago,
        end_time: Time.current
      )
      expect(service_1day.send(:select_table)).to eq('internet_quality_raw')
    end

    it 'uses 5m table for > 2 days and <= 30 days' do
      service_7days = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 7.days.ago,
        end_time: Time.current
      )
      expect(service_7days.send(:select_table)).to eq('internet_quality_5m')
    end

    it 'uses 1h table for > 30 days and <= 1 year' do
      service_60days = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 60.days.ago,
        end_time: Time.current
      )
      expect(service_60days.send(:select_table)).to eq('internet_quality_1h')
    end

    it 'uses 1d table for > 1 year' do
      service_2years = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 400.days.ago,
        end_time: Time.current
      )
      expect(service_2years.send(:select_table)).to eq('internet_quality_1d')
    end
  end

  describe '#build_timeseries_query' do
    context 'with raw table (short time range)' do
      it 'generates correct SQL with both metrics' do
        query = service.send(:build_timeseries_query)

        expect(query).to include('avg(latency_ms) AS avg_latency_ms')
        expect(query).to include('avg(loss_pct) AS avg_loss_pct')
        expect(query).to include('internet_quality_raw')
        expect(query).to include('ts')
        expect(query).to include("org_id = '#{org_id}'")
        expect(query).to include("device_id = '#{device_id}'")
      end
    end

    context 'with aggregated table (longer time range)' do
      let(:service_7days) do
        described_class.new(
          org_id: org_id,
          device_id: device_id,
          start_time: 7.days.ago,
          end_time: Time.current,
          bucket_minutes: 60
        )
      end

      before do
        allow_any_instance_of(described_class).to receive(:client).and_return(mock_client)
      end

      it 'generates correct SQL for aggregated tables' do
        query = service_7days.send(:build_timeseries_query)

        expect(query).to include('avg(sum_latency / samples) AS avg_latency_ms')
        expect(query).to include('avg(sum_loss / samples) AS avg_loss_pct')
        expect(query).to include('sum(samples) AS sample_count')
        expect(query).to include('internet_quality_5m')
      end
    end

    it 'includes GROUP BY clause' do
      query = service.send(:build_timeseries_query)

      expect(query).to include('GROUP BY bucket_time, uplink_id, uplink_type')
    end

    it 'includes ORDER BY clause' do
      query = service.send(:build_timeseries_query)

      expect(query).to include('ORDER BY bucket_time, uplink_id')
    end

    it 'uses correct raw table name constant' do
      expect(described_class::RAW_TABLE).to eq('internet_quality_raw')
    end

    it 'uses correct 5m table name constant' do
      expect(described_class::TABLE_5M).to eq('internet_quality_5m')
    end

    it 'uses correct 1h table name constant' do
      expect(described_class::TABLE_1H).to eq('internet_quality_1h')
    end

    it 'uses correct 1d table name constant' do
      expect(described_class::TABLE_1D).to eq('internet_quality_1d')
    end
  end

  describe '#build_where_conditions' do
    it 'includes required conditions' do
      conditions = service.send(:build_where_conditions)

      expect(conditions).to include("org_id = '#{org_id}'")
      expect(conditions).to include("device_id = '#{device_id}'")
    end

    it 'includes optional uplink_id when provided' do
      conditions = service.send(:build_where_conditions)

      expect(conditions).to include("uplink_id = '#{uplink_id}'")
    end

    it 'includes optional uplink_type when provided' do
      conditions = service.send(:build_where_conditions)

      expect(conditions).to include("uplink_type = '#{uplink_type}'")
    end

    context 'without optional filters' do
      let(:service_minimal) do
        described_class.new(
          org_id: org_id,
          device_id: device_id,
          start_time: start_time,
          end_time: end_time
        )
      end

      it 'excludes uplink_id when not provided' do
        conditions = service_minimal.send(:build_where_conditions)

        expect(conditions).not_to include("uplink_id")
      end

      it 'excludes uplink_type when not provided' do
        conditions = service_minimal.send(:build_where_conditions)

        expect(conditions).not_to include("uplink_type")
      end
    end
  end

  describe '#build_metric_series' do
    it 'returns correct data structure for latency metric' do
      result = service.send(:build_metric_series, mock_clickhouse_data, :latency)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2) # 2 different uplinks

      fiber_uplink = result.find { |u| u[:uplink_id] == 'uplink-fiber-01' }
      expect(fiber_uplink[:uplink_type]).to eq('fiber')
      expect(fiber_uplink[:timeseries]).to be_an(Array)
      expect(fiber_uplink[:timeseries].first).to have_key(:avg_latency_ms)
      expect(fiber_uplink[:timeseries].first[:avg_latency_ms]).to eq(25.5)
    end

    it 'returns correct data structure for loss metric' do
      result = service.send(:build_metric_series, mock_clickhouse_data, :loss)

      expect(result).to be_an(Array)

      fiber_uplink = result.find { |u| u[:uplink_id] == 'uplink-fiber-01' }
      expect(fiber_uplink[:timeseries].first).to have_key(:avg_loss_pct)
      expect(fiber_uplink[:timeseries].first[:avg_loss_pct]).to eq(1.2)
    end

    it 'handles nil avg_latency_ms' do
      data_with_nil = [ { 'bucket_time' => 1.hour.ago, 'uplink_id' => 'uplink-001', 'uplink_type' => 'fiber', 'avg_latency_ms' => nil, 'sample_count' => 0 } ]
      result = service.send(:build_metric_series, data_with_nil, :latency)

      expect(result.first[:timeseries].first[:avg_latency_ms]).to eq(0)
    end

    it 'handles nil avg_loss_pct' do
      data_with_nil = [ { 'bucket_time' => 1.hour.ago, 'uplink_id' => 'uplink-001', 'uplink_type' => 'fiber', 'avg_loss_pct' => nil, 'sample_count' => 0 } ]
      result = service.send(:build_metric_series, data_with_nil, :loss)

      expect(result.first[:timeseries].first[:avg_loss_pct]).to eq(0)
    end

    it 'handles nil sample_count' do
      data_with_nil = [ { 'bucket_time' => 1.hour.ago, 'uplink_id' => 'uplink-001', 'uplink_type' => 'fiber', 'avg_latency_ms' => 25.0, 'sample_count' => nil } ]
      result = service.send(:build_metric_series, data_with_nil, :latency)

      expect(result.first[:timeseries].first[:sample_count]).to eq(0)
    end

    it 'rounds metric values to 2 decimal places' do
      data_with_decimals = [ { 'bucket_time' => 1.hour.ago, 'uplink_id' => 'uplink-001', 'uplink_type' => 'fiber', 'avg_latency_ms' => 25.567, 'avg_loss_pct' => 1.234, 'sample_count' => 100 } ]

      latency_result = service.send(:build_metric_series, data_with_decimals, :latency)
      expect(latency_result.first[:timeseries].first[:avg_latency_ms]).to eq(25.57)

      loss_result = service.send(:build_metric_series, data_with_decimals, :loss)
      expect(loss_result.first[:timeseries].first[:avg_loss_pct]).to eq(1.23)
    end
  end

  describe '#get_uplink_type_from_results' do
    it 'returns correct uplink_type for matching uplink_id' do
      result = service.send(:get_uplink_type_from_results, mock_clickhouse_data, 'uplink-fiber-01')

      expect(result).to eq('fiber')
    end

    it 'returns correct uplink_type for different uplink_id' do
      result = service.send(:get_uplink_type_from_results, mock_clickhouse_data, 'uplink-4g-01')

      expect(result).to eq('4g')
    end

    it 'returns unknown for non-existent uplink_id' do
      result = service.send(:get_uplink_type_from_results, mock_clickhouse_data, 'non-existent')

      expect(result).to eq('unknown')
    end

    it 'returns unknown for empty results' do
      result = service.send(:get_uplink_type_from_results, [], 'uplink-fiber-01')

      expect(result).to eq('unknown')
    end
  end

  describe '#calculate_time_ago' do
    it 'formats seconds correctly' do
      result = service.send(:calculate_time_ago, 30.seconds.ago)
      expect(result).to eq("30s ago")
    end

    it 'formats minutes correctly' do
      result = service.send(:calculate_time_ago, 5.minutes.ago)
      expect(result).to eq("5m ago")
    end

    it 'formats hours correctly' do
      result = service.send(:calculate_time_ago, 2.hours.ago)
      expect(result).to eq("2h ago")
    end

    it 'formats days correctly' do
      result = service.send(:calculate_time_ago, 3.days.ago)
      expect(result).to eq("3d ago")
    end

    it 'handles nil timestamp' do
      result = service.send(:calculate_time_ago, nil)
      expect(result).to eq("N/A")
    end
  end

  describe 'error handling' do
    context 'when ClickHouse query fails' do
      before do
        allow(mock_client).to receive(:select_all).and_raise(StandardError.new("ClickHouse connection error"))
      end

      it 'propagates the error' do
        expect { service.call }.to raise_error(StandardError, "ClickHouse connection error")
      end
    end

    context 'with empty results' do
      before do
        allow(mock_client).to receive(:select_all).and_return([])
      end

      it 'returns empty uplinks arrays' do
        result = service.call

        expect(result[:latency]).to eq([])
        expect(result[:loss]).to eq([])
      end

      it 'still includes time_window' do
        result = service.call

        expect(result[:time_window]).to be_present
        expect(result[:time_window][:start_time]).to eq(start_time)
        expect(result[:time_window][:end_time]).to eq(end_time)
      end
    end
  end

  describe 'edge cases' do
    context 'with nil uplink_id in results' do
      let(:mock_clickhouse_data_with_nil) do
        [
          {
            'bucket_time' => 1.hour.ago,
            'uplink_id' => nil,
            'uplink_type' => 'fiber',
            'avg_latency_ms' => 25.5,
            'avg_loss_pct' => 1.2,
            'sample_count' => 100
          }
        ]
      end

      before do
        allow(mock_client).to receive(:select_all).and_return(mock_clickhouse_data_with_nil)
      end

      it 'handles nil uplink_id by using unknown' do
        result = service.call

        expect(result[:latency].first[:uplink_id]).to eq('unknown')
      end
    end

    context 'with nil uplink_type in results' do
      let(:mock_clickhouse_data_nil_type) do
        [
          {
            'bucket_time' => 1.hour.ago,
            'uplink_id' => 'uplink-001',
            'uplink_type' => nil,
            'avg_latency_ms' => 25.5,
            'avg_loss_pct' => 1.2,
            'sample_count' => 100
          }
        ]
      end

      before do
        allow(mock_client).to receive(:select_all).and_return(mock_clickhouse_data_nil_type)
      end

      it 'returns unknown when uplink_type is nil in results' do
        result = service.call

        # get_uplink_type_from_results returns 'unknown' when uplink_type is nil
        expect(result[:latency].first[:uplink_type]).to eq('unknown')
      end
    end

    context 'with zero sample count' do
      let(:mock_clickhouse_data_zero_samples) do
        [
          {
            'bucket_time' => 1.hour.ago,
            'uplink_id' => 'uplink-001',
            'uplink_type' => 'fiber',
            'avg_latency_ms' => nil,
            'avg_loss_pct' => nil,
            'sample_count' => 0
          }
        ]
      end

      before do
        allow(mock_client).to receive(:select_all).and_return(mock_clickhouse_data_zero_samples)
      end

      it 'handles zero samples gracefully for latency' do
        result = service.call
        timeseries = result[:latency].first[:timeseries].first

        expect(timeseries[:avg_latency_ms]).to eq(0)
        expect(timeseries[:sample_count]).to eq(0)
      end

      it 'handles zero samples gracefully for loss' do
        result = service.call
        timeseries = result[:loss].first[:timeseries].first

        expect(timeseries[:avg_loss_pct]).to eq(0)
        expect(timeseries[:sample_count]).to eq(0)
      end
    end

    context 'with nil bucket_time' do
      let(:mock_clickhouse_data_nil_time) do
        [
          {
            'bucket_time' => nil,
            'uplink_id' => 'uplink-001',
            'uplink_type' => 'fiber',
            'avg_latency_ms' => 25.5,
            'avg_loss_pct' => 1.2,
            'sample_count' => 100
          }
        ]
      end

      before do
        allow(mock_client).to receive(:select_all).and_return(mock_clickhouse_data_nil_time)
      end

      it 'handles nil bucket_time' do
        result = service.call
        timeseries = result[:latency].first[:timeseries].first

        expect(timeseries[:timestamp]).to be_nil
        expect(timeseries[:epoch_ts]).to be_nil
        expect(timeseries[:time_ago]).to eq("N/A")
      end
    end

    context 'with multiple uplinks' do
      it 'groups data correctly by uplink' do
        result = service.call

        fiber_uplink = result[:latency].find { |u| u[:uplink_id] == 'uplink-fiber-01' }
        g4_uplink = result[:latency].find { |u| u[:uplink_id] == 'uplink-4g-01' }

        expect(fiber_uplink[:timeseries].length).to eq(2)
        expect(g4_uplink[:timeseries].length).to eq(1)
      end
    end
  end

  describe 'table selection based on time range' do
    it 'queries raw table for short time ranges' do
      expect(mock_client).to receive(:select_all).with(a_string_including('internet_quality_raw')).once
      service.call
    end

    it 'queries raw table for medium time ranges' do
      service_1day = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 1.day.ago,
        end_time: Time.current
      )
      allow_any_instance_of(described_class).to receive(:client).and_return(mock_client)
      expect(mock_client).to receive(:select_all).with(a_string_including('internet_quality_raw')).once
      service_1day.call
    end

    it 'queries 5m table for week time ranges' do
      service_7days = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 7.days.ago,
        end_time: Time.current
      )
      allow_any_instance_of(described_class).to receive(:client).and_return(mock_client)
      expect(mock_client).to receive(:select_all).with(a_string_including('internet_quality_5m')).once
      service_7days.call
    end

    it 'queries 1h table for month time ranges' do
      service_60days = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 60.days.ago,
        end_time: Time.current
      )
      allow_any_instance_of(described_class).to receive(:client).and_return(mock_client)
      expect(mock_client).to receive(:select_all).with(a_string_including('internet_quality_1h')).once
      service_60days.call
    end

    it 'queries 1d table for multi-year time ranges' do
      service_2years = described_class.new(
        org_id: org_id,
        device_id: device_id,
        start_time: 400.days.ago,
        end_time: Time.current
      )
      allow_any_instance_of(described_class).to receive(:client).and_return(mock_client)
      expect(mock_client).to receive(:select_all).with(a_string_including('internet_quality_1d')).once
      service_2years.call
    end

    it 'does not use router_metrics tables' do
      expect(mock_client).not_to receive(:select_all).with(a_string_including('router_metrics'))
      allow(mock_client).to receive(:select_all).and_return(mock_clickhouse_data)
      service.call
    end
  end

  describe 'TimeAgoCalculator integration' do
    it 'includes TimeAgoCalculator module' do
      expect(described_class.ancestors).to include(TimeAgoCalculator)
    end
  end
end
