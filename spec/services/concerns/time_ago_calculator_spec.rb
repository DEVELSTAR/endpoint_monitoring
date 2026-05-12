# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TimeAgoCalculator, type: :concern do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include TimeAgoCalculator

      # Make the private method public for testing
      public :calculate_time_ago
    end
  end

  let(:test_instance) { test_class.new }

  describe '#calculate_time_ago' do
    let(:current_time) { Time.current }

    before do
      allow(Time).to receive(:current).and_return(current_time)
    end

    context 'with nil timestamp' do
      it 'returns N/A' do
        expect(test_instance.calculate_time_ago(nil)).to eq("N/A")
      end
    end

    context 'with Time objects' do
      it 'formats seconds correctly' do
        timestamp = current_time - 30.seconds
        expect(test_instance.calculate_time_ago(timestamp)).to eq("30s ago")
      end

      it 'formats minutes and seconds correctly' do
        timestamp = current_time - 5.minutes - 30.seconds
        expect(test_instance.calculate_time_ago(timestamp)).to eq("5m ago")
      end

      it 'formats hours and minutes correctly' do
        timestamp = current_time - 2.hours - 30.minutes
        expect(test_instance.calculate_time_ago(timestamp)).to eq("2h ago")
      end

      it 'formats days and hours correctly' do
        timestamp = current_time - 3.days - 5.hours
        expect(test_instance.calculate_time_ago(timestamp)).to eq("3d ago")
      end

      it 'formats only hours when minutes are zero' do
        timestamp = current_time - 2.hours
        expect(test_instance.calculate_time_ago(timestamp)).to eq("2h ago")
      end

      it 'formats only days when hours are zero' do
        timestamp = current_time - 5.days
        expect(test_instance.calculate_time_ago(timestamp)).to eq("5d ago")
      end
    end

    context 'with DateTime objects' do
      it 'converts and formats correctly' do
        timestamp = current_time.to_datetime - 1.hour
        expect(test_instance.calculate_time_ago(timestamp)).to eq("1h ago")
      end
    end

    context 'with Date objects' do
      it 'converts and formats correctly' do
        timestamp = current_time.to_date - 2.days
        result = test_instance.calculate_time_ago(timestamp)
        expect(result).to match(/2d ago|3d ago/)
      end
    end

    context 'with string timestamps' do
      it 'parses ISO8601 format correctly' do
        timestamp = (current_time - 1.hour).iso8601
        expect(test_instance.calculate_time_ago(timestamp)).to eq("1h ago")
      end

      it 'parses standard format correctly' do
        timestamp = (current_time - 30.minutes).strftime("%Y-%m-%d %H:%M:%S")
        expect(test_instance.calculate_time_ago(timestamp)).to eq("30m ago")
      end
    end

    context 'with numeric timestamps (Unix)' do
      it 'converts Unix timestamp correctly' do
        timestamp = (current_time - 45.minutes).to_i
        expect(test_instance.calculate_time_ago(timestamp)).to eq("45m ago")
      end
    end

    context 'with future timestamps' do
      it 'handles future timestamps' do
        timestamp = current_time + 1.hour
        expect(test_instance.calculate_time_ago(timestamp)).to eq("in the future")
      end
    end

    context 'with invalid timestamps' do
      it 'returns N/A for invalid string' do
        expect(test_instance.calculate_time_ago("invalid_timestamp")).to eq("N/A")
      end

      it 'returns N/A for unparseable object' do
        expect(test_instance.calculate_time_ago("Not a valid date 2024")).to eq("N/A")
      end
    end

    context 'edge cases' do
      it 'handles zero seconds' do
        timestamp = current_time
        expect(test_instance.calculate_time_ago(timestamp)).to eq("0s ago")
      end

      it 'handles exactly 1 minute' do
        timestamp = current_time - 60.seconds
        expect(test_instance.calculate_time_ago(timestamp)).to eq("1m ago")
      end

      it 'handles exactly 1 hour' do
        timestamp = current_time - 1.hour
        expect(test_instance.calculate_time_ago(timestamp)).to eq("1h ago")
      end

      it 'handles exactly 1 day' do
        timestamp = current_time - 1.day
        expect(test_instance.calculate_time_ago(timestamp)).to eq("1d ago")
      end
    end

    context 'logging' do
      it 'logs debug message for invalid timestamps' do
        allow(Rails.logger).to receive(:debug)

        test_instance.calculate_time_ago("invalid")

        expect(Rails.logger).to have_received(:debug).with(
           /UtcTimeParser: Failed to normalize invalid: no time information in \"invalid UTC\"/
        )
      end
    end
  end
end
