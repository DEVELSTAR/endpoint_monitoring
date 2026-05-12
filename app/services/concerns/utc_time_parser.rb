# app/services/concerns/utc_time_parser.rb
module UtcTimeParser
  extend ActiveSupport::Concern

  private

  def parse_time_utc(value, default = nil)
    convert_to_utc(value) || default
  rescue StandardError => e
    Rails.logger.debug "UtcTimeParser: Failed to parse #{value}: #{e.message}"
    default
  end

  def parse_time_utc!(value)
    parse_time_utc(value) || raise(ArgumentError, "Unable to parse time: #{value}")
  end

  def normalize_to_utc(value)
    convert_to_utc(value)
  rescue StandardError => e
    Rails.logger.debug "UtcTimeParser: Failed to normalize #{value}: #{e.message}"
    nil
  end

  def convert_to_utc(value)
    return if value.blank?
    return value.utc if value.is_a?(Time)
    return value.to_time.utc if value.is_a?(Date) || value.is_a?(DateTime)
    return Time.at(value).utc if value.is_a?(Numeric)

    str = value.to_s
    str += " UTC" unless str.match?(/(Z|[+-]\d{2}(:?\d{2})?|UTC|GMT|CST|EST|PST)$/i)
    Time.parse(str).utc
  end

  def current_time_utc
    Time.current.utc
  end

  def time_ago_utc(amount, unit = :minutes)
    current_time_utc - amount.public_send(unit)
  end
end
