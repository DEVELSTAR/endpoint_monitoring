class EndpointMonitoringEndpointSerializer < ActiveModel::Serializer
  # Base attributes always shown
  attributes :id, :name, :host, :monitoring_mode
  
  # ICMP-specific attributes
  attribute :latency_critical, if: :icmp_mode?
  attribute :latency_warning, if: :icmp_mode?
  
  # HTTP-specific attributes
  attribute :response_time, if: :http_mode?
  attribute :acceptable_response_codes, if: :http_mode?
  
  # TCP-specific attributes
  attribute :port, if: :tcp_mode?
  
  def icmp_mode?
    object.monitoring_mode == 'icmp'
  end
  
  def http_mode?
    object.monitoring_mode == 'http'
  end
  
  def tcp_mode?
    object.monitoring_mode == 'tcp'
  end
end
