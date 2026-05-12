# app/services/cloud_controller/sync_endpoint_monitoring.rb
module CloudController
  class SyncEndpointMonitoring
    def initialize(associated_resources:, auth_token:)
      @associated_resources = associated_resources
      @auth_token = auth_token
    end

    def call
      puts "done"
    #   response = HTTParty.post(
    #     "#{ENV['CLOUD_CONTROLLER_BASE_URL']}/api/v1/inventory/update_epmc",
    #     headers: {
    #       "Content-Type" => "application/json",
    #       "X-AUTH-TOKEN" => @auth_token
    #     },
    #     body: { associated_resources: @associated_resources, request_type: "endpoint_monitoring" }.to_json,
    #     timeout: 30
    #   )
    #   Rails.logger.warn("CloudController sync failed: #{response.code}") unless response.success?
    #   response
    # rescue => e
    #     Rails.logger.error("CloudController sync error: #{e.message}")
    #     nil
    end
  end
end
