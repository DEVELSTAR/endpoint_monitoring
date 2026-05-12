# app/services/concerns/time_ago_calculator.rb
# Shared concern for calculating human-readable time differences
# Provides consistent time_ago formatting across all services
module TimeAgoCalculator
  extend ActiveSupport::Concern
  include UtcTimeParser

  private

  # Calculate human-readable time difference from a timestamp
  # Handles various timestamp formats and provides consistent output
  #
  # @param timestamp_value [Time, DateTime, String, nil] - The timestamp to compare
  # @return [String] - Human-readable time difference (e.g., "2h 30m ago", "5s ago", "N/A")
  def calculate_time_ago(timestamp_value)
    return "N/A" if timestamp_value.nil?

    begin
      timestamp = normalize_timestamp(timestamp_value)
      return "N/A" if timestamp.nil?

      diff_seconds = (Time.current - timestamp).to_f

      # Handle future timestamps
      return "in the future" if diff_seconds < 0

      format_time_difference(diff_seconds)
    rescue StandardError => e
      Rails.logger.debug "TimeAgoCalculator: Failed to parse timestamp #{timestamp_value}: #{e.message}"
      "N/A"
    end
  end

  # Normalize various timestamp formats to UTC Time object
  def normalize_timestamp(timestamp_value)
    normalize_to_utc(timestamp_value)
  end

  # Format time difference into human-readable string
  def format_time_difference(diff_seconds)
    total_seconds = diff_seconds.to_i

    days = total_seconds / 86400
    hours = (total_seconds % 86400) / 3600
    minutes = (total_seconds % 3600) / 60
    seconds = total_seconds % 60

    # Format based on the largest unit
    case total_seconds
    when 0..59
      "#{seconds}s ago"
    when 60..3599
      "#{minutes}m ago"
    when 3600..86399
      "#{hours}h ago"
    else
      "#{days}d ago"
    end
  end

  def build_time_window(start_time, end_time, bucket_minutes: nil)
    {
      start_time: start_time,
      end_time: end_time,
      bucket_minutes: bucket_minutes
    }.compact
  end
end
