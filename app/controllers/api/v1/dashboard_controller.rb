module Api
  module V1
    class DashboardController < ApplicationController
      include Pagination
      include ClickhouseTableSelector
      before_action :authenticate_user!
      authorize_resource class: false
      before_action :set_org_id

      # Latency Analysis - Network Performance Dashboard (Donut Chart)
      # GET /api/v1/dashboard/latency_analysis
      def latency_analysis
        service_params = build_service_params(
          group_by: params[:group_by] || "endpoint_id"
        )

        execute_service(LatencyAnalysisService, service_params)
      end

      # Endpoint Reports - Time Bucketed Endpoint Status Percentages
      # GET /api/v1/dashboard/endpoint_reports
      def endpoint_reports
        service_params = build_service_params(
          group_by: params[:group_by] || "endpoint_id"
        )

        execute_service(EndpointReportsService, service_params)
      end

      # Site Distribution - Dynamic Network Analysis by Group
      # GET /api/v1/dashboard/site_distribution
      def site_distribution
        service_params = build_service_params(
          group_by: params[:group_by] || "endpoint_id",
          bucket_size: params[:bucket_size]
        )

        execute_service(SiteDistributionService, service_params)
      end

      # Endpoint Metrics - Detailed Metrics with Grouping Support
      # GET /api/v1/dashboard/endpoint_metrics
      def endpoint_metrics
        service_params = build_service_params(
          group_by: params[:group_by] || "endpoint_id",
          page: params[:page],
          per_page: params[:per_page]
        )

        execute_service(EndpointMetricsService, service_params)
      end

      # Grouped Timeseries - Filtered Performance Timeseries Analysis
      # GET /api/v1/dashboard/grouped_timeseries
      # Returns timeseries data based on applied filters (endpoint_id, host, region, etc.)
      def grouped_timeseries
        service_params = build_service_params(
          bucket_minutes: params[:bucket_minutes]
        )

        execute_service(GroupedTimeseriesService, service_params)
      end

      # Endpoint Health Metrics - Comprehensive Endpoint Health Dashboard
      # GET /api/v1/dashboard/endpoint_health_metrics
      def endpoint_health_metrics
        service_params = build_service_params(
          group_by: params[:group_by] || "endpoint_id"
        )
        execute_service(EndpointHealthMetricsService, service_params)
      end

      # Resource List - Dashboard Filter Dropdown Values
      # GET /api/v1/dashboard/resource_list
      def resource_list
        # Collect allowed filters
        filter_fields = %w[
          device_id host endpoint_id region
          location_network_id router_inventory_id isp
        ]

        filters = []

        filter_fields.each do |field|
          value = params[field]
          next if value.blank?

          # ClickHouse values are strings, so safe quoting
          filters << "#{field} = '#{value}'"
        end

        # Always filter by org_id
        where_clause = [ "org_id = '#{@org_id}'" ]
        where_clause += filters
        final_where = where_clause.join(" AND ")

        query = <<~SQL
          SELECT
            groupArray(DISTINCT region) AS regions,
            groupArray(DISTINCT isp) AS isps
          FROM router_metrics_rollup
          WHERE #{final_where}
        SQL

        ch_result = Clickhouse::Base.connection.select_one(query) || {}

        db_result = DashboardResourceService.new(@org_id).call

        render json: {
          mac_ids: db_result[:mac_ids] || [],
          hosts: db_result[:hosts] || [],
          endpoint_ids: db_result[:endpoint_ids] || [],
          regions: ch_result["regions"] || [],
          location_network_ids: db_result[:location_network_ids] || [],
          router_inventory_ids: db_result[:router_inventory_ids] || [],
          isps: ch_result["isps"] || []
        }
      rescue => e
        render_internal_error(e)
      end

      # Uplink Timeseries - Device Uplink Performance Analysis
      # GET /api/v1/dashboard/uplink_timeseries
      def uplink_timeseries
        return unless require_param(:device_id)

        service_params = build_service_params(
          uplink_id: params[:uplink_id],
          uplink_type: params[:uplink_type],
          bucket_minutes: params[:bucket_minutes] || 1
        )

        execute_service(UplinkTimeseriesService, service_params)
      end

      # Location Endpoints - Region-wise Endpoint Details
      # GET /api/v1/dashboard/location_endpoints
      def location_endpoints
        service_params = build_service_params(
          group_by: params[:group_by] || "regions"
        )

        execute_service(LocationEndpointsService, service_params)
      end

      # Endpoint Timeseries - Full 24-hour timeseries for a single endpoint
      # GET /api/v1/dashboard/endpoint_timeseries
      def endpoint_timeseries
        return unless require_param(:endpoint_id)

        service_params = build_service_params(
          bucket_minutes: params[:bucket_minutes] || 15
        )

        execute_service(EndpointTimeseriesService, service_params)
      end

      # Endpoint Location Status - Location-Level Status for Specific Endpoint
      # GET /api/v1/dashboard/endpoint_location_status
      # Shows whether an endpoint is up or down at each location based on threshold comparison
      def endpoint_location_status
        return unless require_param(:endpoint_id)

        service_params = build_service_params(
          page: params[:page],
          per_page: params[:per_page]
        )

        execute_service(EndpointLocationStatusService, service_params)
      end

      # Endpoint Locations - Get location networks and devices for an endpoint
      # GET /api/v1/dashboard/endpoint_locations
      def endpoint_locations
        return unless require_param(:endpoint_id)

        service_params = build_service_params(
          group_by: params[:group_by] || "locations"
        )

        execute_service(EndpointLocationsService, service_params)
      end

    private

      def set_org_id
        @org_id = current_user&.organisation_id
        render json: { error: "org_id is required" }, status: :bad_request unless @org_id.present?
      end

      def require_param(param)
        unless params[param].present?
          render json: { error: "#{param} is required" }, status: :bad_request
          return false
        end
        true
      end

      def resolve_time_window(params)
        if params[:last_minutes].present?
          minutes = params[:last_minutes].to_i
          [ minutes.minutes.ago.utc, current_time_utc ]

        elsif params[:date].present?
          begin
            date = Date.parse(params[:date].to_s)

            start_time = date.beginning_of_day.utc
            end_time   = date.next_day.beginning_of_day.utc   # better than end_of_day

            [ start_time, end_time ]
          rescue ArgumentError
            [ 24.hours.ago.utc, current_time_utc ]
          end

        else
          start_time = parse_time_utc(params[:start_time], 24.hours.ago.utc)
          end_time   = parse_time_utc(params[:end_time], current_time_utc)

          [ start_time, end_time ]
        end
      end

      def execute_service(service_class, service_params)
        service = service_class.new(**service_params)
        render json: service.call, status: :ok
      rescue => e
        render_internal_error(e)
      end

      def build_common_filters(additional_params = {})
        base_filters = {
          org_id: @org_id,
          host: params[:host],
          endpoint_id: params[:endpoint_id],
          isp: params[:isp],
          region: params[:region],
          location_id: params[:location_id],
          device_id: params[:device_id],
          router_id: params[:router_id],
          sites_type: params[:sites_type]
        }

        base_filters.merge(additional_params)
      end

      def build_service_params(additional_params = {})
        # Resolve time window once for all services
        start_time_obj, end_time_obj = resolve_time_window(params)

        # Build complete service parameters
        service_params = build_common_filters.merge(
          start_time: start_time_obj,
          end_time: end_time_obj
        ).merge(additional_params)

        service_params
      end

      def render_internal_error(exception)
        Rails.logger.error(exception.backtrace.first(10).join("\n"))

        render json: {
          status: 500,
          error: "Internal Server Error",
          message: exception.message
        }, status: :internal_server_error
      end
    end
  end
end
