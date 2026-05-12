# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::DashboardController#endpoint_location_status", type: :request do
  let(:org_id) { 3 }
  let(:endpoint_id) { "endpoint-456" }
  let(:user) { create(:admin_user, organisation_id: org_id) }
  let(:access_token) { "valid-token" }

  let(:service_response) do
    {
      time_window: {
        start_time: 24.hours.ago.utc,
        end_time: Time.current.utc,
        duration_hours: 24.0
      },
      endpoint: {
        endpoint_id: endpoint_id,
        name: "Google DNS",
        monitoring_mode: "ICMP",
        thresholds: {
          good_latency: 50,
          warning_latency: 100
        }
      },
      summary: {
        location_network_count: 2,
        up_locations: 1,
        down_locations: 1,
        up_percentage: 50.0,
        down_percentage: 50.0,
        isp_count: 2,
        region_count: 2,
        router_inventory_count: 3,
        device_count: 5,
        avg_latency_ms: 85.5
      },
      location_networks: [
        {
          location_network_id: "loc-001",
          region: "Mumbai",
          isp: "Airtel",
          isp_count: 1,
          region_count: 1,
          router_inventory_count: 2,
          device_count: 3,
          avg_latency_ms: 30.5,
          sample_count: 100,
          status: "up",
          up_since: 2.hours.ago.utc.to_s
        },
        {
          location_network_id: "loc-002",
          region: "Delhi",
          isp: "Jio",
          isp_count: 1,
          region_count: 1,
          router_inventory_count: 1,
          device_count: 2,
          avg_latency_ms: 150.0,
          sample_count: 80,
          status: "down",
          down_since: 1.hour.ago.utc.to_s
        }
      ],
      meta: {
        current_page: 1,
        next_page: nil,
        prev_page: nil,
        total_pages: 1,
        total_count: 2
      }
    }
  end

  before do
    allow_any_instance_of(Api::V1::DashboardController).to receive(:authenticate_user!)
    allow_any_instance_of(Api::V1::DashboardController).to receive(:current_user).and_return(user)
  end

  describe "GET /api/v1/dashboard/endpoint_location_status" do
    context "with valid parameters" do
      before do
        allow_any_instance_of(EndpointLocationStatusService).to receive(:call).and_return(service_response)
      end

      it "returns location status for the endpoint" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response).to include(:time_window, :endpoint, :summary, :location_networks, :meta)
        expect(json_response[:endpoint][:endpoint_id]).to eq(endpoint_id)
        expect(json_response[:location_networks].size).to eq(2)
      end

      it "includes correct summary statistics" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        json_response = JSON.parse(response.body, symbolize_names: true)
        summary = json_response[:summary]

        expect(summary[:location_network_count]).to eq(2)
        expect(summary[:up_locations]).to eq(1)
        expect(summary[:down_locations]).to eq(1)
        expect(summary[:up_percentage]).to eq(50.0)
        expect(summary[:down_percentage]).to eq(50.0)
      end

      it "includes location details with status" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        json_response = JSON.parse(response.body, symbolize_names: true)
        locations = json_response[:location_networks]

        up_location = locations.find { |l| l[:status] == "up" }
        expect(up_location).to be_present
        expect(up_location).to have_key(:up_since)
        expect(up_location[:location_network_id]).to eq("loc-001")

        down_location = locations.find { |l| l[:status] == "down" }
        expect(down_location).to be_present
        expect(down_location).to have_key(:down_since)
        expect(down_location[:location_network_id]).to eq("loc-002")
      end

      it "passes time window parameters to service" do
        start_time = 48.hours.ago.utc.iso8601
        end_time = Time.current.utc.iso8601

        expect(EndpointLocationStatusService).to receive(:new).with(
          hash_including(
            org_id: org_id,
            endpoint_id: endpoint_id,
            start_time: kind_of(Time),
            end_time: kind_of(Time)
          )
        ).and_return(instance_double(EndpointLocationStatusService, call: service_response))

        get "/api/v1/dashboard/endpoint_location_status",
          params: {
            endpoint_id: endpoint_id,
            start_time: start_time,
            end_time: end_time,
            access_token: access_token
          },
          headers: { "Authorization" => "Bearer #{access_token}" }

        expect(response).to have_http_status(:ok)
      end

      it "supports pagination parameters" do
        expect(EndpointLocationStatusService).to receive(:new).with(
          hash_including(
            page: "2",
            per_page: "25"
          )
        ).and_return(instance_double(EndpointLocationStatusService, call: service_response))

        get "/api/v1/dashboard/endpoint_location_status",
          params: {
            endpoint_id: endpoint_id,
            page: 2,
            per_page: 25,
            access_token: access_token
          },
          headers: { "Authorization" => "Bearer #{access_token}" }

        expect(response).to have_http_status(:ok)
      end

      it "includes pagination metadata" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        json_response = JSON.parse(response.body, symbolize_names: true)
        meta = json_response[:meta]

        expect(meta).to include(:current_page, :next_page, :prev_page, :total_pages, :total_count)
        expect(meta[:current_page]).to eq(1)
        expect(meta[:total_count]).to eq(2)
      end
    end

    context "without endpoint_id parameter" do
      it "returns bad request error" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("endpoint_id is required")
      end
    end

    context "with invalid authentication" do
      before do
        allow_any_instance_of(Api::V1::DashboardController).to receive(:authenticate_user!)
          .and_raise(StandardError.new("Invalid token"))
      end

      it "returns unauthorized error" do
        expect {
          get "/api/v1/dashboard/endpoint_location_status",
            params: { endpoint_id: endpoint_id, access_token: "invalid-token" }
        }.to raise_error(StandardError)
      end
    end

    context "without organization_id" do
      before do
        allow(user).to receive(:organisation_id).and_return(nil)
      end

      it "returns bad request error" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("org_id is required")
      end
    end

    context "when service raises an error" do
      before do
        allow_any_instance_of(EndpointLocationStatusService).to receive(:call)
          .and_raise(StandardError.new("Database connection error"))
      end

      it "returns internal server error" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        expect(response).to have_http_status(:internal_server_error)

        json_response = JSON.parse(response.body)
        expect(json_response["status"]).to eq(500)
        expect(json_response["error"]).to eq("Internal Server Error")
      end
    end

    context "with empty results" do
      let(:empty_response) do
        service_response.merge(
          location_networks: [],
          summary: {
            location_network_count: 0,
            up_locations: 0,
            down_locations: 0,
            up_percentage: 0.0,
            down_percentage: 0.0,
            isp_count: 0,
            region_count: 0,
            router_inventory_count: 0,
            device_count: 0,
            avg_latency_ms: 0.0
          },
          meta: {
            current_page: 1,
            next_page: nil,
            prev_page: nil,
            total_pages: 0,
            total_count: 0
          }
        )
      end

      before do
        allow_any_instance_of(EndpointLocationStatusService).to receive(:call).and_return(empty_response)
      end

      it "returns empty location networks" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:location_networks]).to be_empty
        expect(json_response[:summary][:location_network_count]).to eq(0)
        expect(json_response[:meta][:total_count]).to eq(0)
      end
    end

    context "with multiple pages of results" do
      let(:paginated_response) do
        service_response.merge(
          meta: {
            current_page: 2,
            next_page: 3,
            prev_page: 1,
            total_pages: 5,
            total_count: 100
          }
        )
      end

      before do
        allow_any_instance_of(EndpointLocationStatusService).to receive(:call).and_return(paginated_response)
      end

      it "returns correct pagination metadata" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, page: 2, per_page: 20, access_token: access_token },
          headers: { "Authorization" => "Bearer #{access_token}" }

        json_response = JSON.parse(response.body, symbolize_names: true)
        meta = json_response[:meta]

        expect(meta[:current_page]).to eq(2)
        expect(meta[:next_page]).to eq(3)
        expect(meta[:prev_page]).to eq(1)
        expect(meta[:total_pages]).to eq(5)
        expect(meta[:total_count]).to eq(100)
      end
    end

    context "with token in params instead of headers" do
      before do
        allow_any_instance_of(EndpointLocationStatusService).to receive(:call).and_return(service_response)
      end

      it "authenticates successfully" do
        get "/api/v1/dashboard/endpoint_location_status",
          params: { endpoint_id: endpoint_id, access_token: access_token }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
