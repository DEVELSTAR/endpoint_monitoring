class EpConfigMapping < ApplicationRecord
  belongs_to :endpoint_monitoring_group

  after_commit :cache_to_redis, on: %i[create update], unless: :test_environment?
  after_commit :delete_from_redis, on: :destroy, unless: :test_environment?

  def cache_to_redis
    $redis.hset(redis_key, serialized_mapping)
  end

  def delete_from_redis
    remaining_epg_ids = endpoint_monitoring_group_ids

    if remaining_epg_ids.any?
      $redis.hset(redis_key, "EPG_IDS", remaining_epg_ids.join(","))
    else
      $redis.del(redis_key)
    end
  end

  def redis_key
    case resourceable_type
    when "LocationNetwork"
      "LN:#{resourceable_id}"
    when "RouterInventory"
      "AP:#{RouterInventory.find_by(id: resourceable_id)&.mac_id}"
    when "ActsAsTaggableOn::Tag"
      "TAG:#{resourceable_id}"
    else
      "#{resourceable_type&.first(2)&.upcase}:#{resourceable_id}"
    end
  end

  def serialized_mapping
    {
      "EPG_IDS" => endpoint_monitoring_group_ids.join(",")
    }
  end

  def endpoint_monitoring_group_ids
    EpConfigMapping.where(resourceable_type: resourceable_type, resourceable_id: resourceable_id).map do |mapping|
      "EPG:#{mapping.endpoint_monitoring_group_id}"
    end
  end

  private

  def test_environment?
    Rails.env.test?
  end
end
