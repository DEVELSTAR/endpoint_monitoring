# spec/requests/api/v1/endpoint_monitoring_groups_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::EndpointMonitoringGroups", type: :request do
  let!(:user) { create(:admin_user) }
  let!(:groups) { create_list(:endpoint_monitoring_group, 3, :with_endpoints, user: user) }
  let(:group_id) { groups.first.id }
  let(:headers) { { "X-AUTH-TOKEN" => user.access_token } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  shared_examples "not_found" do
    it "returns 404" do
      subject
      expect(response).to have_http_status(:not_found)
    end
  end

  shared_examples "unprocessable_content" do
    it "returns errors" do
      subject
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end
  end

  describe "GET /index" do
    subject { get "/api/v1/endpoint_monitoring_groups", params: params, headers: headers }
    let(:params) { {} }

    it "returns paginated groups with endpoints" do
      subject
      json = JSON.parse(response.body)
      expect(json["endpoint_monitoring_groups"].size).to eq(3)
      expect(response).to have_http_status(:ok)
    end

    it "includes endpoints and mappings" do
      subject
      json = JSON.parse(response.body)
      groups_data = json["endpoint_monitoring_groups"]
      expect(groups_data.first).to have_key("endpoint_monitoring_endpoints")
      expect(groups_data.first["endpoint_monitoring_endpoints"]).to be_an(Array)
    end

    it "orders by created_at desc" do
      subject
      json = JSON.parse(response.body)
      groups_data = json["endpoint_monitoring_groups"]
      ids = groups_data.map { |g| g["id"] }
      expect(ids).to eq(groups.map(&:id).reverse)
    end

    context "with pagination" do
      let(:params) { { page: 1, per_page: 2 } }

      it "returns correct number of items per page" do
        subject
        json = JSON.parse(response.body)
        expect(json["endpoint_monitoring_groups"].size).to eq(2)
      end

      it "includes pagination metadata" do
        subject
        json = JSON.parse(response.body)
        expect(json["meta"]).to be_present
        expect(json["meta"]).to have_key("current_page")
        expect(json["meta"]).to have_key("total_pages")
        expect(json["meta"]).to have_key("total_count")
      end
    end

    context "with second page" do
      let(:params) { { page: 2, per_page: 2 } }

      it "returns remaining items" do
        subject
        json = JSON.parse(response.body)
        expect(json["endpoint_monitoring_groups"].size).to eq(1)
      end
    end

    context "with custom per_page" do
      let(:params) { { per_page: 1 } }

      it "respects per_page parameter" do
        subject
        json = JSON.parse(response.body)
        expect(json["endpoint_monitoring_groups"].size).to eq(1)
      end
    end

    context "when user has no groups" do
      let!(:groups) { [] }

      it "returns not found status with message" do
        subject
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("No endpoint monitoring groups found")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /show" do
    subject { get "/api/v1/endpoint_monitoring_groups/#{id}", headers: headers }

    context "when record exists" do
      let(:id) { group_id }

      before do
        create(:ep_config_mapping,
               endpoint_monitoring_group: groups.first,
               resourceable_type: "RouterInventory",
               resourceable_id: 42)
      end

      it "returns the group with endpoints and mappings" do
        subject
        json = JSON.parse(response.body)["endpoint_monitoring_group"]
        expect(json["id"]).to eq(group_id)
        expect(json["endpoint_monitoring_endpoints"]).not_to be_empty
        expect(json["associated_resources"]).not_to be_empty
        expect(response).to have_http_status(:ok)
      end
    end

    context "when record does not exist" do
      let(:id) { 999_999 }
      it_behaves_like "not_found"
    end
  end

  describe "POST /create" do
    let(:valid_params) do
      {
        endpoint_monitoring_group: {
          name: "New Group",
          group_type: "network",
          associated_resources: [ "AP:10", "network:5" ],
          endpoint_monitoring_endpoints_attributes: [
            {
              name: "Google DNS",
              host: "8.8.8.8",
              monitoring_mode: "icmp",
              port: 53,
              latency_critical: 200,
              latency_warning: 100,
              response_time: 50,
              acceptable_response_codes: [ 200 ]
            }
          ]
        }
      }
    end

    subject { post "/api/v1/endpoint_monitoring_groups", params: params, headers: headers }

    context "with valid parameters" do
      let(:params) { valid_params }

      before do
        # Create the required resources for associated_resources
        create(:router_inventory, id: 10)
        create(:location_network, id: 5)
      end

      it "creates group, endpoints, and mappings" do
        expect { subject }.to change(EndpointMonitoringGroup, :count).by(1)
          .and change(EndpointMonitoringEndpoint, :count).by(1)
          .and change(EpConfigMapping, :count).by(2)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Endpoint monitoring group created successfully")
      end

      it "sets the user association" do
        subject
        group = EndpointMonitoringGroup.last
        expect(group.user).to eq(user)
      end

      it "sets the organisation_id from current_user" do
        subject
        group = EndpointMonitoringGroup.last
        expect(group.organisation_id).to eq(user.organisation_id)
      end

      it "returns success message in response" do
        subject
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Endpoint monitoring group created successfully")
        expect(response).to have_http_status(:created)
      end
    end

    context "activity logging" do
      let(:params) { valid_params }

      before do
        create(:router_inventory, id: 10)
        create(:location_network, id: 5)
      end

      it "records an activity for the group creation" do
        expect do
          subject
        end.to change {
          Activity.where(trackable_type: "EndpointMonitoringGroup").count
        }.by(1)

        new_group = EndpointMonitoringGroup.order(:created_at).last
        activity = Activity.find_by(
          trackable_type: "EndpointMonitoringGroup",
          trackable_id: new_group.id,
          key: "endpoint_monitoring_group.create"
        )
        expect(activity).to be_present
      end
    end

    context "with multiple endpoints" do
      let(:params) do
        {
          endpoint_monitoring_group: {
            name: "Multi Endpoint Group",
            group_type: "network",
            endpoint_monitoring_endpoints_attributes: [
              {
                name: "Endpoint 1",
                host: "1.1.1.1",
                monitoring_mode: "icmp",
                latency_critical: 300,
                latency_warning: 200
              },
              {
                name: "Endpoint 2",
                host: "http://example.com",
                monitoring_mode: "http",
                response_time: 500,
                acceptable_response_codes: [ 200, 301 ]
              }
            ]
          }
        }
      end

      before do
        router = create(:router_inventory)
        params[:endpoint_monitoring_group][:associated_resources] = [ "AP:#{router.id}" ]
      end

      it "creates all endpoints" do
        expect { subject }.to change(EndpointMonitoringEndpoint, :count).by(2)
        expect(response).to have_http_status(:created)
      end
    end

    context "without associated_resources" do
      let(:params) do
        {
          endpoint_monitoring_group: {
            name: "Simple Group",
            group_type: "network"
          }
        }
      end

      it "fails validation for missing associated_resources" do
        expect { subject }.not_to change(EndpointMonitoringGroup, :count)
        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["errors"]).to include("Associated resources can't be blank")
      end
    end

    context "with invalid parameters" do
      let(:params) { { endpoint_monitoring_group: { name: "" } } }

      it_behaves_like "unprocessable_content"

      it "does not create any records" do
        expect { subject }.not_to change(EndpointMonitoringGroup, :count)
      end
    end

    context "with invalid nested endpoint" do
      let(:params) do
        {
          endpoint_monitoring_group: {
            name: "Valid Group",
            group_type: "network",
            endpoint_monitoring_endpoints_attributes: [
              {
                name: "",
                host: "",
                monitoring_mode: "icmp"
              }
            ]
          }
        }
      end

      it "returns validation errors" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    context "with response_time outside allowed range" do
      before do
        create(:router_inventory, id: 10)
        create(:location_network, id: 5)
      end

      let(:base_params) do
        {
          endpoint_monitoring_group: {
            name: "HTTP Group",
            group_type: "network",
            associated_resources: [ "AP:10", "network:5" ],
            endpoint_monitoring_endpoints_attributes: [
              {
                name: "HTTP Endpoint",
                host: "https://example.com",
                monitoring_mode: "http",
                acceptable_response_codes: [ 200 ]
              }
            ]
          }
        }
      end

      context "when response_time is below minimum" do
        let(:params) do
          base_params.deep_merge(
            endpoint_monitoring_group: {
              endpoint_monitoring_endpoints_attributes: [
                { response_time: 4 }
              ]
            }
          )
        end

        it "returns validation error mentioning minimum value" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["errors"].to_s).to include("Response time 4 is outside the allowed range between 5 and 3000.")
        end
      end

      context "when response_time is above maximum" do
        let(:params) do
          base_params.deep_merge(
            endpoint_monitoring_group: {
              endpoint_monitoring_endpoints_attributes: [
                { response_time: 4000 }
              ]
            }
          )
        end

        it "returns validation error mentioning maximum value" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["errors"].to_s).to include("Response time 4000 is outside the allowed range between 5 and 3000.")
        end
      end
    end

    context "when creation is forbidden due to access control" do
      let(:params) { valid_params }

      it "returns forbidden status with locked resource message" do
        user.role.update(name: "user")
        subject
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:forbidden)
        expect(json["error"]).to eq("Requested resource is locked. You cannot do this operation.")
      end
    end
  end

  describe "PUT /update" do
    subject { put "/api/v1/endpoint_monitoring_groups/#{id}", params: params, headers: headers }
    let(:id) { group_id }

    context "with valid parameters" do
      let(:params) { { endpoint_monitoring_group: { name: "Updated Name", associated_resources: [ "tag:99" ] } } }

      before do
        # Create the required tag resource
        create(:tag, id: 99)
      end

      it "updates group attributes and associated resources" do
        subject
        group = EndpointMonitoringGroup.find(group_id)
        expect(group.name).to eq("Updated Name")
        expect(group.ep_config_mappings.first.resourceable_type).to eq("ActsAsTaggableOn::Tag")
        expect(group.ep_config_mappings.first.resourceable_id).to eq(99)
        expect(response).to have_http_status(:ok)
      end

      it "returns success message in response" do
        subject
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Endpoint monitoring group updated successfully")
        expect(response).to have_http_status(:ok)
      end
    end

    context "with nested endpoint attributes" do
      let!(:endpoint) { groups.first.endpoint_monitoring_endpoints.first || create(:endpoint_monitoring_endpoint, endpoint_monitoring_group: groups.first) }
      let(:params) do
        {
          endpoint_monitoring_group: {
            name: "Updated Group",
            endpoint_monitoring_endpoints_attributes: [
              {
                id: endpoint.id,
                name: "Updated Endpoint Name",
                host: "1.1.1.1",
                latency_critical: 500
              }
            ]
          }
        }
      end

      before do
        router = create(:router_inventory)
        params[:endpoint_monitoring_group][:associated_resources] = [ "AP:#{router.id}" ]
      end

      it "updates nested endpoints" do
        subject
        endpoint.reload
        expect(endpoint.name).to eq("Updated Endpoint Name")
        expect(endpoint.host).to eq("1.1.1.1")
        expect(endpoint.latency_critical).to eq(500)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with endpoint destruction" do
      let!(:endpoint) { groups.first.endpoint_monitoring_endpoints.first || create(:endpoint_monitoring_endpoint, endpoint_monitoring_group: groups.first) }
      let(:params) do
        {
          endpoint_monitoring_group: {
            endpoint_monitoring_endpoints_attributes: [
              {
                id: endpoint.id,
                _destroy: true
              }
            ]
          }
        }
      end

      before do
        router = create(:router_inventory)
        params[:endpoint_monitoring_group][:associated_resources] = [ "AP:#{router.id}" ]
      end

      it "destroys the endpoint" do
        expect { subject }.to change(EndpointMonitoringEndpoint, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid parameters" do
      let(:params) { { endpoint_monitoring_group: { name: "" } } }

      it "returns validation errors" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end

      it "does not update the group" do
        original_name = groups.first.name
        subject
        groups.first.reload
        expect(groups.first.name).to eq(original_name)
      end
    end

    context "when group does not exist" do
      let(:id) { 999_999 }
      let(:params) { { endpoint_monitoring_group: { name: "Test" } } }

      it_behaves_like "not_found"
    end

    context "when updating group_type" do
      let(:params) { { endpoint_monitoring_group: { group_type: "location" } } }

      before do
        router = create(:router_inventory)
        params[:endpoint_monitoring_group][:associated_resources] = [ "AP:#{router.id}" ]
      end

      it "updates the group_type" do
        subject
        groups.first.reload
        expect(groups.first.group_type).to eq("location")
        expect(response).to have_http_status(:ok)
      end
    end

    context "when update is forbidden due to access control" do
      let(:params) { { endpoint_monitoring_group: { name: "Blocked Update" } } }

      it "returns forbidden status with locked resource message" do
        user.role.update(name: "user")
        subject
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:forbidden)
        expect(json["error"]).to eq("Requested resource is locked. You cannot do this operation.")
      end
    end

    context "activity logging" do
      let(:params) { { endpoint_monitoring_group: { name: "Activity Logged Name" } } }

      before do
        router = create(:router_inventory)
        params[:endpoint_monitoring_group][:associated_resources] = [ "AP:#{router.id}" ]
      end

      it "records an activity for the group update" do
        expect do
          subject
        end.to change {
          Activity.where(trackable_type: "EndpointMonitoringGroup", key: "endpoint_monitoring_group.update").count
        }.by(1)

        activity = Activity.where(trackable_type: "EndpointMonitoringGroup", key: "endpoint_monitoring_group.update").order(:created_at).last
        expect(activity.trackable_id).to eq(group_id)
        expect(activity.trackable_type).to eq("EndpointMonitoringGroup")
      end
    end
  end

  describe "DELETE /destroy" do
    subject { delete "/api/v1/endpoint_monitoring_groups/#{id}", headers: headers }
    let!(:group) { groups.first }
    let(:id) { group.id }

    before do
      create(:ep_config_mapping, endpoint_monitoring_group: group, resourceable_type: "RouterInventory", resourceable_id: 42)
    end

    it "deletes group and cascades mappings" do
      expect { subject }.to change(EndpointMonitoringGroup, :count).by(-1)
        .and change(EpConfigMapping, :count).by(groups.first.ep_config_mappings.count * -1)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Endpoint monitoring group deleted successfully")
    end

    it "cascades deletion to endpoints" do
      endpoints_count = group.endpoint_monitoring_endpoints.count
      expect { subject }.to change(EndpointMonitoringEndpoint, :count).by(-endpoints_count)
    end

    it "returns success message" do
      subject
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Endpoint monitoring group deleted successfully")
      expect(response).to have_http_status(:ok)
    end

    context "when group does not exist" do
      let(:id) { 999_999 }

      it_behaves_like "not_found"

      it "does not delete any records" do
        expect { subject }.not_to change(EndpointMonitoringGroup, :count)
      end
    end

    context "when trying to delete another user's group" do
      let!(:other_user) { create(:user) }
      let!(:other_group) { create(:endpoint_monitoring_group, user: other_user) }
      let(:id) { other_group.id }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end

      it "does not delete the group" do
        initial_count = EndpointMonitoringGroup.count
        subject
        expect(EndpointMonitoringGroup.count).to eq(initial_count)
      end
    end

    context "when deletion is forbidden due to access control" do
      it "returns forbidden status with locked resource message" do
        user&.role&.update(name: "user")
        subject
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:forbidden)
        expect(json["error"]).to eq("Requested resource is locked. You cannot do this operation.")
      end
    end

    context "activity logging" do
      it "records an activity for the group deletion" do
        expect do
          subject
        end.to change {
          Activity.where(trackable_type: "EndpointMonitoringGroup", key: "endpoint_monitoring_group.destroy").count
        }.by(1)

        activity = Activity.where(trackable_type: "EndpointMonitoringGroup", key: "endpoint_monitoring_group.destroy").order(:created_at).last
        expect(activity.trackable_id).to eq(group.id)
        expect(activity.trackable_type).to eq("EndpointMonitoringGroup")
      end
    end
  end
end
