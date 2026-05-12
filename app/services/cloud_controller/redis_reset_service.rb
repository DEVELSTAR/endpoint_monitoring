# app/services//cloud_controller/redis_reset_service.rb
module CloudController
  class RedisResetService
    attr_reader :results, :errors

    def initialize(auth_token: nil)
      @auth_token = auth_token
      @results = {
        endpoint_monitoring_groups: { status: "success" },
        ep_config_mappings: { status: "success" },
        cloud_controller_sync: { status: "not_attempted" }
      }
      @errors = []
    end

    def call
      begin
        reset_endpoint_monitoring_groups
        reset_ep_config_mappings
        sync_cloud_controller unless Rails.env.test?

        {
          success: true,
          message: "Redis data has been reset successfully",
          results: @results,
          errors: @errors
        }
      rescue StandardError => e
        {
          success: false,
          message: "Redis reset failed: #{e.message}",
          results: @results,
          errors: @errors
        }
      end
    end

    private

    def reset_endpoint_monitoring_groups
      groups = EndpointMonitoringGroup.includes(:endpoint_monitoring_endpoints)

      groups.find_each do |group|
        begin
          redis_key = "EPG:#{group.id}"
          serialized_data = {
            "INT" => "30",
            "HOSTS" => group.endpoint_monitoring_endpoints.map do |endpoint|
              {
                "MODE" => mode_mapping(endpoint.monitoring_mode),
                "PORT" => endpoint.port.to_s,
                "HOST" => endpoint.host,
                "ID" => endpoint.id.to_s
              }.compact
            end
          }

          $redis.set(redis_key, serialized_data.to_json)
        rescue StandardError => e
          @results[:endpoint_monitoring_groups][:status] = "failed"
          @errors << "EPG #{group.id}: #{e.message}"
        end
      end
    end

    def reset_ep_config_mappings
      mappings_grouped = EpConfigMapping.all.group_by do |mapping|
        [ mapping.resourceable_type, mapping.resourceable_id ]
      end

      mappings_grouped.each do |(resourceable_type, resourceable_id), mappings|
        begin
          redis_key = build_redis_key(resourceable_type, resourceable_id)
          epg_ids = mappings.map { |m| "EPG:#{m.endpoint_monitoring_group_id}" }

          $redis.hset(redis_key, "EPG_IDS", epg_ids.join(","))
        rescue StandardError => e
          @results[:ep_config_mappings][:status] = "failed"
          @errors << "Mapping #{resourceable_type}:#{resourceable_id}: #{e.message}"
        end
      end
    end

    def build_redis_key(resourceable_type, resourceable_id)
      case resourceable_type
      when "LocationNetwork"
        "LN:#{resourceable_id}"
      when "RouterInventory"
        router = RouterInventory.find_by(id: resourceable_id)
        "AP:#{router&.mac_id}"
      when "ActsAsTaggableOn::Tag"
        "TAG:#{resourceable_id}"
      else
        "#{resourceable_type&.first(2)&.upcase}:#{resourceable_id}"
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

    def sync_cloud_controller
      begin
        associated_resources = collect_all_associated_resources

        if associated_resources.empty?
          @results[:cloud_controller_sync][:status] = "skipped"
          return
        end

        response = SyncEndpointMonitoring.new(
          associated_resources: associated_resources,
          auth_token: @auth_token
        ).call

        if response && response.success?
          @results[:cloud_controller_sync][:status] = "success"
        else
          @results[:cloud_controller_sync][:status] = "failed"
          @errors << "Cloud Controller sync failed: #{response&.code || 'connection error'}"
        end
      rescue StandardError => e
        @results[:cloud_controller_sync][:status] = "error"
        @errors << "Cloud Controller sync error: #{e.message}"
      end
    end

    def collect_all_associated_resources
      associated_resources = []
      unique_mappings = EpConfigMapping.pluck(:resourceable_type, :resourceable_id).uniq

      unique_mappings.each do |resourceable_type, resourceable_id|
        resource_string = build_resource_string(resourceable_type, resourceable_id)
        associated_resources << resource_string if resource_string.present?
      end

      associated_resources
    end

    def build_resource_string(resourceable_type, resourceable_id)
      case resourceable_type
      when "LocationNetwork"
        "network:#{resourceable_id}"
      when "RouterInventory"
        "AP:#{resourceable_id}"
      when "ActsAsTaggableOn::Tag"
        "tag:#{resourceable_id}"
      else
        nil
      end
    end
  end
end
