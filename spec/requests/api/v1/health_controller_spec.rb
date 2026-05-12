require 'rails_helper'

RSpec.describe Api::V1::HealthController, type: :request do
  let(:user) { create(:admin_user) }
  let(:headers) { { "X-AUTH-TOKEN" => user.access_token } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    # Mock authorize_resource for class: false
    allow_any_instance_of(Api::V1::HealthController).to receive(:authorize!).and_return(true)
  end

  describe "GET /api/v1/health" do
    context "when all services are healthy" do
      before do
        # Mock all successful connections
        allow(ApplicationRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
        allow(CloudControllerRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
        allow(Clickhouse::Base).to receive(:execute_sql_one).and_return({ "test" => 1 })
        allow($redis).to receive(:set).and_return("OK")
        allow($redis).to receive(:get).and_return("ok")
        allow($redis).to receive(:del).and_return(1)
        allow(Rails.cache).to receive(:write).and_return(true)
        allow(Rails.cache).to receive(:read).and_return("ok")
        allow(Rails.cache).to receive(:delete).and_return(true)
      end

      it "returns a successful health check" do
        get "/api/v1/health", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response["status"]).to eq("ok")
        expect(json_response).to have_key("timestamp")
        expect(json_response).to have_key("uptime")
        expect(json_response).to have_key("checks")
      end

      it "includes all required health checks" do
        get "/api/v1/health", headers: headers

        json_response = JSON.parse(response.body)
        checks = json_response["checks"]
        
        expect(checks).to have_key("database_primary")
        expect(checks).to have_key("database_legacy")
        expect(checks).to have_key("clickhouse")
        expect(checks).to have_key("redis")
        expect(checks).to have_key("cache")
        expect(checks).not_to have_key("sidekiq")
        expect(checks).not_to have_key("last_activity")
      end

      it "shows all services as healthy" do
        get "/api/v1/health", headers: headers

        json_response = JSON.parse(response.body)
        checks = json_response["checks"]
        
        checks.each do |service, result|
          expect(result["status"]).to eq("ok"), "Service #{service} should be healthy"
        end
      end
    end

    context "when database connections fail" do
      before do
        allow(ApplicationRecord.connection).to receive(:execute).and_raise(StandardError.new("DB connection failed"))
        allow(CloudControllerRecord.connection).to receive(:execute).and_raise(StandardError.new("Legacy DB connection failed"))
        allow(Clickhouse::Base).to receive(:execute_sql_one).and_raise(StandardError.new("ClickHouse connection failed"))
        
        # Other mocks to prevent real calls
        allow($redis).to receive(:set).and_return("OK")
        allow($redis).to receive(:get).and_return("ok")
        allow($redis).to receive(:del).and_return(1)
        allow(Rails.cache).to receive(:write).and_return(true)
        allow(Rails.cache).to receive(:read).and_return("ok")
        allow(Rails.cache).to receive(:delete).and_return(true)
      end

      it "returns service unavailable status" do
        get "/api/v1/health", headers: headers

        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        
        expect(json_response["status"]).to eq("error")
        expect(json_response["checks"]["database_primary"]["status"]).to eq("error")
        expect(json_response["checks"]["database_legacy"]["status"]).to eq("error")
        expect(json_response["checks"]["clickhouse"]["status"]).to eq("error")
      end
    end

    context "when Redis fails" do
      before do
        allow(ApplicationRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
        allow(CloudControllerRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
        allow(Clickhouse::Base).to receive(:execute_sql_one).and_return({ "test" => 1 })
        allow($redis).to receive(:set).and_raise(StandardError.new("Redis connection failed"))
        allow(Rails.cache).to receive(:write).and_return(true)
        allow(Rails.cache).to receive(:read).and_return("ok")
        allow(Rails.cache).to receive(:delete).and_return(true)
      end

      it "returns service unavailable status" do
        get "/api/v1/health", headers: headers

        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        
        expect(json_response["status"]).to eq("error")
        expect(json_response["checks"]["redis"]["status"]).to eq("error")
      end
    end

    context "when Cache fails" do
      before do
        allow(ApplicationRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
        allow(CloudControllerRecord.connection).to receive(:execute).and_return([{ "test" => 1 }])
        allow(Clickhouse::Base).to receive(:execute_sql_one).and_return({ "test" => 1 })
        allow($redis).to receive(:set).and_return("OK")
        allow($redis).to receive(:get).and_return("ok")
        allow($redis).to receive(:del).and_return(1)
        allow(Rails.cache).to receive(:write).and_raise(StandardError.new("Cache connection failed"))
      end

      it "returns service unavailable status" do
        get "/api/v1/health", headers: headers

        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        
        expect(json_response["status"]).to eq("error")
        expect(json_response["checks"]["cache"]["status"]).to eq("error")
      end
    end

    context "when unauthorized" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_call_original
        allow(User).to receive(:find_by).with(access_token: 'invalid').and_return(nil)
      end

      it "returns unauthorized status" do
        get "/api/v1/health", headers: { "X-AUTH-TOKEN" => "invalid" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

