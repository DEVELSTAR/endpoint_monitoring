# spec/requests/api/v1/dashboard_location_endpoints_spec.rb
require 'rails_helper'

RSpec.describe "Dashboard Location Endpoints API", type: :request do
  let(:user) { create(:admin_user) }
  let(:headers) { { "X-AUTH-TOKEN" => user.access_token } }
  let(:client_double) { instance_double('Clickhouse::Connection') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow(Clickhouse::Base).to receive(:connection).and_return(client_double)
  end

  describe "GET /api/v1/dashboard/location_endpoints" do
    subject { get "/api/v1/dashboard/location_endpoints", params: params, headers: headers }
    let(:params) { {} }

    let(:mock_response) do
      [
        {
          "endpoint_id" => "1",
          "region" => "Delhi",
          "avg_latency_ms" => 50.0,
          "http_errors" => 0,
          "tcp_failures" => 0,
          "sample_count" => 100
        },
        {
          "endpoint_id" => "2",
          "region" => "Delhi",
          "avg_latency_ms" => 150.0,
          "http_errors" => 10,
          "tcp_failures" => 0,
          "sample_count" => 100
        },
        {
          "endpoint_id" => "3",
          "region" => "Mumbai",
          "avg_latency_ms" => 250.0,
          "http_errors" => 0,
          "tcp_failures" => 0,
          "sample_count" => 100
        }
      ]
    end

    before do
      allow(client_double).to receive(:select_all).and_return(mock_response)
      # Mock endpoints existing in MySQL - ClickHouse returns string IDs
      endpoints = [
        double('Endpoint', id: 1, latency_warning: 100, latency_critical: 200, monitoring_mode: 'icmp'),
        double('Endpoint', id: 2, latency_warning: 100, latency_critical: 200, monitoring_mode: 'icmp'),
        double('Endpoint', id: 3, latency_warning: 100, latency_critical: 200, monitoring_mode: 'icmp')
      ]
      allow(EndpointMonitoringEndpoint).to receive(:where).with(id: %w[1 2 3]).and_return(endpoints)
    end

    it "returns 200 status" do
      subject
      expect(response).to have_http_status(:ok)
    end

    it "returns time_window in response" do
      subject
      json = JSON.parse(response.body)
      expect(json["time_window"]).to be_present
      expect(json["time_window"]["start_time"]).to be_present
      expect(json["time_window"]["end_time"]).to be_present
    end

    it "returns data array with region counts" do
      subject
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
    end

    it "returns correct region structure" do
      subject
      json = JSON.parse(response.body)
      location = json["data"].first

      expect(location).to have_key("region")
      expect(location).to have_key("count")
      expect(location).to have_key("good")
      expect(location).to have_key("warning")
      expect(location).to have_key("critical")
      expect(location).to have_key("down")
    end

    context "with time window parameters" do
      let(:params) do
        {
          start_time: "2023-01-01T00:00:00Z",
          end_time: "2023-01-02T00:00:00Z"
        }
      end

      it "accepts custom time range" do
        subject
        expect(response).to have_http_status(:ok)
      end
    end

    context "when no data available" do
      before do
        allow(client_double).to receive(:select_all).and_return([])
      end

      it "returns empty data array" do
        subject
        json = JSON.parse(response.body)
        expect(json["data"]).to eq([])
      end
    end

    context "when not authenticated" do
      # Don't send any auth headers
      let(:headers) { {} }

      before do
        # Remove the global authentication mocks for this test
        allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_call_original
      end

      it "returns unauthorized status" do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when ClickHouse error occurs" do
      before do
        allow(client_double).to receive(:select_all).and_raise(StandardError.new("ClickHouse connection error"))
        allow(Rails.logger).to receive(:error)
      end

      it "returns internal server error" do
        subject
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
