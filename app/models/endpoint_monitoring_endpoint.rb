class EndpointMonitoringEndpoint < ApplicationRecord
  include PublicActivity::Model
  include ActivityTrackable
  belongs_to :endpoint_monitoring_group

  MONITORING_MODES = %w[icmp tcp http].freeze
  NUMERIC_FIELD_RULES = {
    latency_critical:      { min: 1, max: 3000 },
    latency_warning:       { min: 1, max: 3000 },
    response_time:         { min: 5, max: 3000 },
    port:                  { min: 1, max: 65535 }
  }.freeze

  validates :monitoring_mode, inclusion: {
    in: MONITORING_MODES,
    message: ->(_record, data) do
      value = data[:value].presence || "nil"
      "#{value} is invalid. Allowed values: #{MONITORING_MODES.join(', ')}"
    end
  }, allow_blank: true

  validates :name, :host, :monitoring_mode, presence: true

  # ICMP mode
  validates :latency_critical, :latency_warning,
            presence: true,
            if: -> { monitoring_mode == "icmp" }

  # HTTP mode
  validates :acceptable_response_codes, :response_time,
            presence: true,
            if: -> { monitoring_mode == "http" }

  # TCP mode - binary success/failure, no latency thresholds
  validates :port,
            presence: true,
            if: -> { monitoring_mode == "tcp" }

  validate :validate_host_format

  # Range validations
  validate :validate_numeric_thresholds
  validate :validate_acceptable_response_codes, if: -> { monitoring_mode == "http" }

  track_activity_for "endpoint_monitoring_endpoint"

  # Cache invalidation callbacks
  after_save :clear_endpoint_cache
  after_destroy :clear_endpoint_cache

  private

  def clear_endpoint_cache
    Rails.cache.delete("endpoint_config:#{id}")
    Rails.cache.delete_matched("endpoints:batch:*")
  end

  def validate_host_format
    return if host.blank?

    case monitoring_mode
    when "http"
      validate_http_host
    else # icmp, tcp
      validate_domain_or_ip
    end
  end

  def validate_http_host
    uri = URI.parse(host)

    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:host, "#{host} must be a valid URL with http:// or https://")
      return
    end

    if uri.host.blank?
      errors.add(:host, "#{host} must include a valid host")
    end
  rescue URI::InvalidURIError
    errors.add(:host, "#{host} is not a valid host")
  end

  def validate_domain_or_ip
    valid =
      begin
        IPAddr.new(host)
        true
      rescue IPAddr::InvalidAddressError
        host.match?(/\A(?=.{1,253}\z)(?!-)(?:[a-zA-Z0-9-]{1,63}\.)+[a-zA-Z]{2,63}\z/)
      end

    errors.add(:host, "#{host} is invalid. Provide a valid Host.") unless valid
  end

  def validate_numeric_thresholds
    invalid = false

    NUMERIC_FIELD_RULES.each do |field, rule|
      raw_value = send("#{field}_before_type_cast")
      next if raw_value.blank?

      unless raw_value.to_s.match?(/\A\d+\z/)
        errors.add(field, "#{raw_value} is invalid. Please provide a numeric value#{range_hint(rule)}.")
        invalid = true
        next
      end

      value = raw_value.to_i
      if value < rule[:min] || value > rule[:max]
        errors.add(field, "#{value} is outside the allowed range#{range_hint(rule)}.")
        invalid = true
      end
    end

    return if invalid

    if monitoring_mode == "icmp" && latency_critical.to_i <= latency_warning.to_i
      errors.add(:latency_critical, "#{latency_critical} must be greater than latency warning")
    end
  end

  def invalid_numeric_format?(raw_value)
    return false if raw_value.is_a?(Numeric)

    raw_string = raw_value.to_s.strip
    return false if raw_string.blank?

    !raw_string.match?(/\A-?\d+(\.\d+)?\z/)
  end

  def range_hint(rule)
    min, max = rule.values_at(:min, :max)

    return "" unless min || max
    return " between #{min} and #{max}" if min && max
    return " greater than or equal to #{min}" if min
    " less than or equal to #{max}"
  end

  def validate_acceptable_response_codes
    return errors.add(:acceptable_response_codes, "can't be blank") if acceptable_response_codes.blank?

    acceptable_response_codes.each do |code|
      errors.add(
        :acceptable_response_codes,
        "#{code} is invalid. Use numeric HTTP codes between 100 and 599."
      ) unless code.to_i.between?(100, 599)
    end
  end
end
