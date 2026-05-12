class EndpointMonitoringGroup < ApplicationRecord
  include AssociatedResource
  include PublicActivity::Model
  include ActivityTrackable
  include EndpointThresholdBuilder

  belongs_to :user
  has_many :endpoint_monitoring_endpoints, dependent: :destroy
  accepts_nested_attributes_for :endpoint_monitoring_endpoints, allow_destroy: true

  validates :name, presence: true, uniqueness: { scope: :user_id, message: "is already been taken!" }
  validate :associated_resources_must_be_present
  validate :validate_associated_resources

  track_activity_for "endpoint_monitoring_group"

  after_commit :cache_to_redis, on: %i[create update], unless: :test_environment?
  after_commit :delete_from_redis, on: :destroy, unless: :test_environment?

  MODEL_MAP = {
    "AP"      => RouterInventory,
    "network" => LocationNetwork,
    "tag"     => Tag
  }.freeze

  private

  def associated_resources_must_be_present
    if associated_resources_cache.blank?
      errors.add(:associated_resources, "can't be blank")
    end
  end

  def validate_associated_resources
    return unless associated_resources_cache.present?

    associated_resources_cache.each do |resource_string|
      type_prefix, id = resource_string.split(":")

      # Validate format
      unless type_prefix.in?(%w[AP network tag]) && id.present?
        errors.add(:associated_resources, "Invalid format: #{resource_string}. Expected format: 'AP:id', 'network:id', or 'tag:id'")
        next
      end

      unless id.to_s.match?(/\A\d+\z/)
        errors.add(:associated_resources, "#{type_prefix} ID must be numeric")
        return
      end

      # Validate ID existence based on type
      model = MODEL_MAP[type_prefix]
      if model && !model.exists?(id)
        errors.add(:associated_resources, "#{type_prefix} with ID #{id} does not exist")
      end
    end
  end

  def delete_from_redis
    endpoint_monitoring_endpoints.each do |endpoint|
      $redis.hdel("endpoint_thresholds", endpoint.id)
    end

    $redis.del(redis_key)
  end

  def cache_to_redis
    $redis.set(redis_key, serialized_group.to_json)
    cache_endpoint_thresholds
  end

  def redis_key
    "EPG:#{id}"
  end

  def serialized_group
    {
      "INT" => "30",
      "HOSTS" => endpoint_monitoring_endpoints.map do |endpoint|
        {
          "MODE" => mode_mapping(endpoint.monitoring_mode), # 1:ICMP, 2:TCP, 3:HTTP
          "PORT" => endpoint.port.to_s,
          "HOST" => endpoint.host,
          "ID" => endpoint.id.to_s
        }.compact
      end
    }
  end

  def cache_endpoint_thresholds
    endpoint_monitoring_endpoints.each do |endpoint|
      thresholds = build_threshold_string_for_endpoint(endpoint)
      $redis.hset(
        "endpoint_thresholds",
        endpoint.id,
        thresholds
      )
    end
  end

  def mode_mapping(mode)
    case mode.to_s.downcase
    when "icmp"
      "1"
    when "tcp"
      "2"
    when "http"
      "3"
    else
      "0"
    end
  end

  def test_environment?
    Rails.env.test?
  end
end
