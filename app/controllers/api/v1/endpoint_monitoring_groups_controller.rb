# app/controllers/api/v1/endpoint_monitoring_groups_controller.rb
module Api
  module V1
    class EndpointMonitoringGroupsController < ApplicationController
      include Pagination
      include EndpointThresholdBuilder
      before_action :authenticate_user!
      authorize_resource
      before_action :set_group, only: %i[show update destroy]

      def index
        groups = current_user.endpoint_monitoring_groups
                             .includes(:endpoint_monitoring_endpoints, :ep_config_mappings)
                             .order(created_at: :desc)
                             .page(params[:page])
                             .per(params[:per_page] || 10)

        if groups.any?
          # Batch-load associated resources to eliminate N+1 queries
          resource_cache = build_resource_cache(groups)

          render json: groups, status: :ok, each_serializer: EndpointMonitoringGroupSerializer,
                meta: pagination_meta(groups),
                resource_cache: resource_cache
        else
          render json: { message: "No endpoint monitoring groups found" }, status: :not_found
        end
      end

      def index_stream
        response.headers["Content-Type"] = "text/event-stream"

        groups = current_user.endpoint_monitoring_groups
                             .includes(:endpoint_monitoring_endpoints, :ep_config_mappings)
                             .order(created_at: :desc)

        resource_cache = build_resource_cache(groups)

        begin
          groups.find_each do |group|
            payload = EndpointMonitoringGroupSerializer.new(
              group,
              resource_cache: resource_cache
            ).as_json

            response.stream.write(
              "data: #{payload.to_json}\n\n"
            )

            sleep 0.2 # avoid flooding client
          end
        rescue IOError
          # client disconnected
        ensure
          response.stream.close
        end
      end

      def show
        render json: @group, status: :ok, each_serializer: EndpointMonitoringGroupSerializer
      end

      def create
        group = current_user.endpoint_monitoring_groups.new(endpoint_monitoring_group_params)
        group.organisation_id = current_user.organisation_id

        if group.save
          sync_cloud_controller(group.associated_resources) unless Rails.env.test?

          render json: {
            message: "Endpoint monitoring group created successfully"
          }, status: :created
        else
          render_validation_errors(group)
        end
      end

      def update
        if @group.update(endpoint_monitoring_group_params)
          sync_cloud_controller(@group.associated_resources) unless Rails.env.test?

          render json: {
            message: "Endpoint monitoring group updated successfully"
          }, status: :ok
        else
          render_validation_errors(@group)
        end
      end

      def destroy
        @group.destroy
        render json: {
          message: "Endpoint monitoring group deleted successfully"
        }, status: :ok
      end

      def set_ep_config
        auth_token = request.headers["X-AUTH-TOKEN"] || params["access_token"]
        result = CloudController::RedisResetService.new(auth_token: auth_token).call

        if result[:success]
          render json: {
            data: result[:results],
            errors: result[:errors]
          }, status: :ok
        else
          render json: {
            data: result[:results],
            errors: result[:errors]
          }, status: :internal_server_error
        end
      end

      def set_ep_thresholds
        EndpointMonitoringEndpoint.find_each(batch_size: 500) do |endpoint|
          thresholds = build_threshold_string(endpoint)
          $redis.hset(
            "endpoint_thresholds",
            endpoint.id,
            thresholds
          )
        end
        render json: { message: "Thresholds synced to Redis successfully" }, status: :ok
      end

      private

      def set_group
        @group = current_user.endpoint_monitoring_groups
                            .includes(:endpoint_monitoring_endpoints, :ep_config_mappings)
                            .find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { message: "Endpoint monitoring group not found" }, status: :not_found
      end

      def endpoint_monitoring_group_params
        params.require(:endpoint_monitoring_group).permit(
          :name, :group_type, :organisation_id,
          associated_resources: [],
          endpoint_monitoring_endpoints_attributes: [
            :id, :name, :host, :monitoring_mode, :port,
            :latency_critical, :latency_warning,
            :response_time, :_destroy,
            acceptable_response_codes: []
          ]
        )
      end

      def render_validation_errors(resource)
        render json: { errors: formatted_errors(resource) }, status: :unprocessable_content
      end

      def formatted_errors(resource)
        return [] unless resource&.errors

        resource.errors.full_messages.map do |message|
          sanitize_endpoint_error_prefix(message)
        end.uniq
      end

      def sanitize_endpoint_error_prefix(message)
        cleaned = message.to_s.sub(/\AEndpoint monitoring endpoints\s+/i, "").strip
        cleaned.sub(/\A([a-z])/) { |match| match.upcase }
      end

      def sync_cloud_controller(associated_resources)
        CloudController::SyncEndpointMonitoring.new(
          associated_resources: associated_resources,
          auth_token: request.headers["X-AUTH-TOKEN"] || params["access_token"]
        ).call
      end

      def build_resource_cache(groups)
        ids_by_type = Hash.new { |h, k| h[k] = [] }

        groups.each do |group|
          group.ep_config_mappings.each do |m|
            ids_by_type[m.resourceable_type] << m.resourceable_id
          end
        end

        {
          "RouterInventory"        => [ RouterInventory, :mac_id ],
          "LocationNetwork"        => [ LocationNetwork, :network_name ],
          "ActsAsTaggableOn::Tag"  => [ Tag, :name ]
        }.each_with_object({}) do |(type, (model, field)), cache|
          ids = ids_by_type[type].uniq
          next if ids.empty?

          model.where(id: ids).find_each do |record|
            cache["#{type}:#{record.id}"] = record.public_send(field)
          end
        end
      end
    end
  end
end
