require 'rails_helper'

RSpec.describe "Api::V1::Dashboard#uplink_timeseries", type: :request do
  let(:user) { create(:admin_user, organisation_id: 123, access_token: "valid_token") }
  let(:valid_token) { "valid_token" }
  let(:device_id) { "device-001" }
  let(:headers) { { 'X-AUTH-TOKEN' => valid_token } }

  let(:service_response) do
    {
      time_window: {
        start_time: 24.hours.ago,
        end_time: Time.current,
        bucket_minutes: 1
      },
      latency: [
        {
          uplink_id: "uplink-fiber-01",
          uplink_type: "fiber",
          timeseries: [
            {
              timestamp: 1.hour.ago,
              epoch_ts: 1.hour.ago.to_i,
              time_ago: "1h ago",
              avg_latency_ms: 25.5,
              sample_count: 100
            }
          ]
        }
      ],
      loss: [
        {
          uplink_id: "uplink-fiber-01",
          uplink_type: "fiber",
          timeseries: [
            {
              timestamp: 1.hour.ago,
              epoch_ts: 1.hour.ago.to_i,
              time_ago: "1h ago",
              avg_loss_pct: 1.2,
              sample_count: 100
            }
          ]
        }
      ]
    }
  end

  before do
    allow(User).to receive(:find_by).with(access_token: valid_token).and_return(user)
    allow(User).to receive(:find_by).with(access_token: "invalid_token").and_return(nil)
    allow(User).to receive(:find_by).with(access_token: nil).and_return(nil)
  end

  describe "GET /api/v1/dashboard/uplink_timeseries" do
    context "with valid authentication" do
      before do
        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)
      end

      it "returns success with required parameters" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key("time_window")
        expect(json).to have_key("latency")
        expect(json).to have_key("loss")
      end

      it "returns correct response structure" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers

        json = JSON.parse(response.body)

        expect(json["latency"]).to be_an(Array)
        expect(json["loss"]).to be_an(Array)
        expect(json["time_window"]).to have_key("bucket_minutes")
      end

      it "accepts optional uplink_id parameter" do
        expect_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)

        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, uplink_id: "uplink-fiber-01" },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it "accepts optional uplink_type parameter" do
        expect_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)

        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, uplink_type: "fiber" },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it "accepts optional bucket_minutes parameter" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, bucket_minutes: 5 },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it "defaults bucket_minutes to 1 when not provided" do
        expect(UplinkTimeseriesService).to receive(:new).with(
          hash_including(bucket_minutes: 1)
        ).and_call_original

        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers
      end

      it "accepts time window parameters" do
        start_time = 2.hours.ago.iso8601
        end_time = Time.current.iso8601

        get "/api/v1/dashboard/uplink_timeseries",
            params: {
              device_id: device_id,
              start_time: start_time,
              end_time: end_time
            },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it "accepts last_minutes parameter" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, last_minutes: 60 },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it "accepts all filter parameters" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: {
              device_id: device_id,
              uplink_id: "uplink-fiber-01",
              uplink_type: "fiber",
              bucket_minutes: 15,
              start_time: 2.hours.ago.iso8601,
              end_time: Time.current.iso8601
            },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it "passes token in params" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, access_token: valid_token }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with missing required parameters" do
      before do
        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)
      end

      it "returns bad request when device_id is missing" do
        get "/api/v1/dashboard/uplink_timeseries",
            headers: headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("device_id")
      end

      it "returns bad request when device_id is empty" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: "" },
            headers: headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with invalid authentication" do
      it "returns unauthorized when token is invalid" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: { 'X-AUTH-TOKEN' => 'invalid_token' }

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized when token is missing" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with user missing organisation_id" do
      let(:user_without_org) { create(:admin_user, organisation_id: nil, access_token: "no_org_token") }

      before do
        allow(User).to receive(:find_by).with(access_token: "no_org_token").and_return(user_without_org)
      end

      it "returns bad request when organisation_id is missing" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: { 'X-AUTH-TOKEN' => 'no_org_token' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("org_id")
      end
    end

    context "when service raises an error" do
      before do
        allow_any_instance_of(UplinkTimeseriesService).to receive(:call)
          .and_raise(StandardError.new("ClickHouse connection error"))
      end

      it "returns internal server error" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers

        expect(response).to have_http_status(:internal_server_error)
      end

      it "returns error message in response" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers

        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end
    end

    context "service integration" do
      it "instantiates service with correct parameters" do
        expect(UplinkTimeseriesService).to receive(:new).with(
          hash_including(
            org_id: 123,
            device_id: device_id
          )
        ).and_call_original

        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)

        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers
      end

      it "passes uplink_id to service" do
        expect(UplinkTimeseriesService).to receive(:new).with(
          hash_including(uplink_id: "uplink-fiber-01")
        ).and_call_original

        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)

        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, uplink_id: "uplink-fiber-01" },
            headers: headers
      end

      it "passes uplink_type to service" do
        expect(UplinkTimeseriesService).to receive(:new).with(
          hash_including(uplink_type: "fiber")
        ).and_call_original

        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)

        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, uplink_type: "fiber" },
            headers: headers
      end

      it "passes bucket_minutes to service" do
        expect(UplinkTimeseriesService).to receive(:new).with(
          hash_including(bucket_minutes: "5")
        ).and_call_original

        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)

        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, bucket_minutes: 5 },
            headers: headers
      end
    end

    context "minimal required parameters" do
      before do
        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)
      end

      it "works with only device_id parameter" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context "with special characters in parameters" do
      before do
        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)
      end

      it "handles special characters in device_id" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: "device-001-special_chars" },
            headers: headers

        expect(response).to have_http_status(:ok)
      end

      it "handles special characters in uplink_id" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id, uplink_id: "uplink_fiber-01.test" },
            headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context "JSON response format" do
      before do
        allow_any_instance_of(UplinkTimeseriesService).to receive(:call).and_return(service_response)
      end

      it "returns JSON content type" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers

        expect(response.content_type).to include("application/json")
      end

      it "returns valid JSON" do
        get "/api/v1/dashboard/uplink_timeseries",
            params: { device_id: device_id },
            headers: headers

        expect { JSON.parse(response.body) }.not_to raise_error
      end
    end
  end
end
