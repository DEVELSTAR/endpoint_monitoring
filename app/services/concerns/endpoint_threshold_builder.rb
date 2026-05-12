# app/services/concerns/endpoint_threshold_builder.rb
module EndpointThresholdBuilder
  extend ActiveSupport::Concern

  def build_threshold_string(endpoint)
    case endpoint.monitoring_mode&.downcase
    when "http"
      "http|#{endpoint.response_time}|#{endpoint.acceptable_response_codes}"
    when "tcp"
      "tcp|1"
    else
      "icmp|#{endpoint.latency_warning}|#{endpoint.latency_critical}"
    end
  end
end
