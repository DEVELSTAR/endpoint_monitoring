require 'rails_helper'

RSpec.describe EndpointMonitoringGroup, type: :model do
  describe 'serialized_group structure' do
    let(:group) { create(:endpoint_monitoring_group) }

    it 'includes correct fields for ICMP mode' do
      endpoint = create(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'icmp',
                        name: 'ICMP Endpoint',
                        host: '8.8.8.8',
                        latency_critical: 300,
                        latency_warning: 200)

      group.endpoint_monitoring_endpoints << endpoint
      group.reload
      data = group.send(:serialized_group)

      expect(data["INT"]).to eq("30")
      expect(data["HOSTS"]).to be_an(Array)

      ep = data["HOSTS"].first
      expect(ep["MODE"]).to eq("1") # ICMP
      expect(ep["HOST"]).to eq("8.8.8.8")
      expect(ep["ID"]).to eq(endpoint.id.to_s)
    end

    it 'includes correct fields for HTTP/WGET modes' do
      endpoint = create(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'http',
                        name: 'HTTP Endpoint',
                        host: 'https://example.com',
                        response_time: 200,
                        acceptable_response_codes: [ 200, 301 ])

      group.endpoint_monitoring_endpoints << endpoint
      group.reload
      data = group.send(:serialized_group)

      expect(data["INT"]).to eq("30")
      expect(data["HOSTS"]).to be_an(Array)

      ep = data["HOSTS"].first
      expect(ep["MODE"]).to eq("3") # HTTP
      expect(ep["HOST"]).to eq("https://example.com")
      expect(ep["ID"]).to eq(endpoint.id.to_s)
    end
  end

  describe 'EndpointMonitoringGroupSerializer' do
    let(:user) { create(:admin_user) }
    let(:group) { create(:endpoint_monitoring_group, user: user, organisation_id: user.organisation_id) }
    let(:serializer) { EndpointMonitoringGroupSerializer.new(group) }
    let(:serialized_data) { JSON.parse(serializer.to_json) }

    describe 'basic attributes serialization' do
      it 'includes all required attributes' do
        expect(serialized_data).to have_key('id')
        expect(serialized_data).to have_key('name')
        expect(serialized_data).to have_key('user_id')
        expect(serialized_data).to have_key('organisation_id')
        expect(serialized_data).to have_key('group_type')
        expect(serialized_data).to have_key('associated_resources')
      end

      it 'serializes id correctly' do
        expect(serialized_data['id']).to eq(group.id)
      end

      it 'serializes name correctly' do
        expect(serialized_data['name']).to eq(group.name)
      end

      it 'serializes user_id correctly' do
        expect(serialized_data['user_id']).to eq(group.user_id)
      end

      it 'serializes organisation_id correctly' do
        expect(serialized_data['organisation_id']).to eq(group.organisation_id)
      end

      it 'serializes group_type correctly' do
        expect(serialized_data['group_type']).to eq(group.group_type)
      end
    end

    describe 'endpoint_monitoring_endpoints association' do
      let!(:endpoint1) { create(:endpoint_monitoring_endpoint, endpoint_monitoring_group: group, name: 'Endpoint 1') }
      let!(:endpoint2) { create(:endpoint_monitoring_endpoint, endpoint_monitoring_group: group, name: 'Endpoint 2') }

      before { group.reload }

      it 'includes endpoint_monitoring_endpoints array' do
        expect(serialized_data).to have_key('endpoint_monitoring_endpoints')
        expect(serialized_data['endpoint_monitoring_endpoints']).to be_an(Array)
      end

      it 'serializes all endpoints' do
        expect(serialized_data['endpoint_monitoring_endpoints'].length).to eq(2)
      end

      it 'uses EndpointMonitoringEndpointSerializer for each endpoint' do
        endpoint_data = serialized_data['endpoint_monitoring_endpoints'].first
        expect(endpoint_data).to have_key('id')
        expect(endpoint_data).to have_key('name')
      end
    end

    describe 'associated_resources method' do
      context 'with no ep_config_mappings' do
        it 'returns empty array' do
          # Group is created with associated_resources (from factory)
          # But we stub ep_config_mappings to return empty to test serialization
          allow(group).to receive(:ep_config_mappings).and_return([])
          serializer = EndpointMonitoringGroupSerializer.new(group)
          data = JSON.parse(serializer.to_json)
          expect(data['associated_resources']).to eq([])
        end
      end

      context 'with RouterInventory mapping' do
        let(:router) { double('RouterInventory', mac_id: '00:11:22:33:44:55') }
        let!(:mapping) { create(:ep_config_mapping,
                                endpoint_monitoring_group: group,
                                resourceable_type: 'RouterInventory',
                                resourceable_id: 123) }

        before do
          allow(RouterInventory).to receive(:find_by).with(id: 123).and_return(router)
          allow(group).to receive(:ep_config_mappings).and_return([ mapping ])
        end

        it 'includes mapping with router mac_id as name' do
          resource = serialized_data['associated_resources'].first
          expect(resource['id']).to eq(mapping.id)
          expect(resource['resourceable_type']).to eq('RouterInventory')
          expect(resource['resourceable_id']).to eq(123)
          expect(resource['endpoint_monitoring_group_id']).to eq(mapping.endpoint_monitoring_group_id)
          expect(resource['name']).to eq('00:11:22:33:44:55')
        end
      end

      context 'with LocationNetwork mapping' do
        let(:location) { double('LocationNetwork', network_name: 'Main Office Network') }
        let!(:mapping) { create(:ep_config_mapping,
                                endpoint_monitoring_group: group,
                                resourceable_type: 'LocationNetwork',
                                resourceable_id: 456) }

        before do
          allow(LocationNetwork).to receive(:find_by).with(id: 456).and_return(location)
          allow(group).to receive(:ep_config_mappings).and_return([ mapping ])
        end

        it 'includes mapping with location network_name as name' do
          resource = serialized_data['associated_resources'].first
          expect(resource['id']).to eq(mapping.id)
          expect(resource['resourceable_type']).to eq('LocationNetwork')
          expect(resource['resourceable_id']).to eq(456)
          expect(resource['name']).to eq('Main Office Network')
        end
      end

      context 'with ActsAsTaggableOn::Tag mapping' do
        let(:tag) { double('ActsAsTaggableOn::Tag', name: 'Production') }
        let!(:mapping) { create(:ep_config_mapping,
                                endpoint_monitoring_group: group,
                                resourceable_type: 'ActsAsTaggableOn::Tag',
                                resourceable_id: 789) }

        before do
          allow(Tag).to receive(:find_by).with(id: 789).and_return(tag)
          allow(group).to receive(:ep_config_mappings).and_return([ mapping ])
        end

        it 'includes mapping with tag name' do
          resource = serialized_data['associated_resources'].first
          expect(resource['id']).to eq(mapping.id)
          expect(resource['resourceable_type']).to eq('ActsAsTaggableOn::Tag')
          expect(resource['resourceable_id']).to eq(789)
          expect(resource['name']).to eq('Production')
        end
      end

      context 'with unknown resourceable_type' do
        let(:unknown_resource) { double('UnknownType', some_field: 'value') }
        let!(:mapping) { create(:ep_config_mapping,
                                endpoint_monitoring_group: group,
                                resourceable_type: 'UnknownType',
                                resourceable_id: 999) }

        before do
          allow(group).to receive(:ep_config_mappings).and_return([ mapping ])
        end

        it 'includes mapping with nil name for unknown types' do
          resource = serialized_data['associated_resources'].first
          expect(resource['id']).to eq(mapping.id)
          expect(resource['resourceable_type']).to eq('UnknownType')
          expect(resource['resourceable_id']).to eq(999)
          expect(resource['name']).to eq('Unknown Resource Type: UnknownType')
        end
      end

      context 'with no cached resourceable' do
        let!(:mapping) { create(:ep_config_mapping,
                                endpoint_monitoring_group: group,
                                resourceable_type: 'RouterInventory',
                                resourceable_id: 111) }

        before do
          allow(RouterInventory).to receive(:find_by).with(id: 111).and_return(nil)
          allow(group).to receive(:ep_config_mappings).and_return([ mapping ])
        end

        it 'returns nil name when resourceable cache is not present' do
          resource = serialized_data['associated_resources'].first
          expect(resource['name']).to eq('Unknown Router')
        end
      end

      context 'with multiple ep_config_mappings of different types' do
        let(:router) { double('RouterInventory', mac_id: 'AA:BB:CC:DD:EE:FF') }
        let(:location) { double('LocationNetwork', network_name: 'Branch Office') }
        let(:tag) { double('ActsAsTaggableOn::Tag', name: 'Critical') }

        let!(:mapping1) { create(:ep_config_mapping,
                                 endpoint_monitoring_group: group,
                                 resourceable_type: 'RouterInventory',
                                 resourceable_id: 1) }
        let!(:mapping2) { create(:ep_config_mapping,
                                 endpoint_monitoring_group: group,
                                 resourceable_type: 'LocationNetwork',
                                 resourceable_id: 2) }
        let!(:mapping3) { create(:ep_config_mapping,
                                 endpoint_monitoring_group: group,
                                 resourceable_type: 'ActsAsTaggableOn::Tag',
                                 resourceable_id: 3) }

        before do
          allow(RouterInventory).to receive(:find_by).with(id: 1).and_return(router)
          allow(LocationNetwork).to receive(:find_by).with(id: 2).and_return(location)
          allow(Tag).to receive(:find_by).with(id: 3).and_return(tag)
          allow(group).to receive(:ep_config_mappings).and_return([ mapping1, mapping2, mapping3 ])
        end

        it 'serializes all mappings with correct names' do
          resources = serialized_data['associated_resources']
          expect(resources.length).to eq(3)

          router_resource = resources.find { |r| r['resourceable_type'] == 'RouterInventory' }
          expect(router_resource['name']).to eq('AA:BB:CC:DD:EE:FF')

          location_resource = resources.find { |r| r['resourceable_type'] == 'LocationNetwork' }
          expect(location_resource['name']).to eq('Branch Office')

          tag_resource = resources.find { |r| r['resourceable_type'] == 'ActsAsTaggableOn::Tag' }
          expect(tag_resource['name']).to eq('Critical')
        end

        it 'includes all required fields for each mapping' do
          resources = serialized_data['associated_resources']
          resources.each do |resource|
            expect(resource).to have_key('id')
            expect(resource).to have_key('resourceable_type')
            expect(resource).to have_key('resourceable_id')
            expect(resource).to have_key('endpoint_monitoring_group_id')
            expect(resource).to have_key('name')
          end
        end
      end
    end

    describe 'complete serialization with all data' do
      let!(:endpoint) { create(:endpoint_monitoring_endpoint, endpoint_monitoring_group: group, name: 'Test Endpoint') }
      let(:router) { double('RouterInventory', mac_id: 'FF:EE:DD:CC:BB:AA') }
      let!(:mapping) { create(:ep_config_mapping,
                              endpoint_monitoring_group: group,
                              resourceable_type: 'RouterInventory',
                              resourceable_id: 555) }

      before do
        allow(RouterInventory).to receive(:find_by).with(id: 555).and_return(router)
        group.reload
      end

      it 'serializes complete group with all associations' do
        # Reload with stubbed resource to bypass validation
        allow(group).to receive(:ep_config_mappings).and_return([ mapping ])
        serializer = EndpointMonitoringGroupSerializer.new(group)
        data = JSON.parse(serializer.to_json)

        expect(data['id']).to eq(group.id)
        expect(data['name']).to eq(group.name)
        expect(data['endpoint_monitoring_endpoints'].length).to eq(1)
        expect(data['associated_resources'].length).to eq(1)
        expect(data['associated_resources'].first['name']).to eq('FF:EE:DD:CC:BB:AA')
      end
    end

    describe 'edge cases' do
      it 'handles nil values gracefully' do
        router = create(:router_inventory)
        group_with_nils = create(:endpoint_monitoring_group,
                                  user: user,
                                  organisation_id: nil,
                                  group_type: nil,
                                  associated_resources: [ "AP:#{router.id}" ])
        serializer = EndpointMonitoringGroupSerializer.new(group_with_nils)
        data = JSON.parse(serializer.to_json)

        expect(data['organisation_id']).to be_nil
        expect(data['group_type']).to be_nil
        expect(data['associated_resources']).to be_an(Array)
      end

      it 'handles empty endpoint associations' do
        expect(serialized_data['endpoint_monitoring_endpoints']).to eq([])
        # associated_resources is now required, so we just check it's an array
        expect(serialized_data['associated_resources']).to be_an(Array)
      end
    end
  end

  describe 'associated_resources= method' do
    let(:user) { create(:admin_user) }
    let(:group) { build(:endpoint_monitoring_group, user: user) }

    context 'with nil input' do
      it 'sets @associated_resources_cache to empty array' do
        group.associated_resources = nil
        expect(group.instance_variable_get(:@associated_resources_cache)).to eq([])
      end
    end

    context 'with array containing blank values' do
      it 'filters out blank values correctly' do
        group.associated_resources = [ "AP:123", "", "network:456", nil, "   ", "\t", "\n" ]
        expect(group.instance_variable_get(:@associated_resources_cache)).to eq([ "AP:123", "network:456" ])
      end
    end

    context 'with array containing only blank values' do
      it 'sets empty array when all values are blank' do
        group.associated_resources = [ "", nil, "   ", "\t", "\n", [] ]
        expect(group.instance_variable_get(:@associated_resources_cache)).to eq([])
      end
    end

    context 'with valid non-blank values' do
      it 'keeps all valid values' do
        group.associated_resources = [ "AP:123", "network:456", "tag:789" ]
        expect(group.instance_variable_get(:@associated_resources_cache)).to eq([ "AP:123", "network:456", "tag:789" ])
      end
    end

    context 'with mixed valid and whitespace-only strings' do
      it 'keeps valid values and filters whitespace-only strings' do
        group.associated_resources = [ "AP:123", "  ", "network:456", "\ttag:789\t", "   " ]
        expect(group.instance_variable_get(:@associated_resources_cache)).to eq([ "AP:123", "network:456", "tag:789" ])
      end
    end
  end

  describe 'associated_resources validation' do
    let(:user) { create(:admin_user) }
    let(:group) { build(:endpoint_monitoring_group, user: user) }

    context 'with valid associated_resources' do
      it 'passes validation when all resources exist' do
        # Create test resources
        router = create(:router_inventory)
        location = create(:location_network)
        tag = create(:tag)

        group.associated_resources = [ "AP:#{router.id}", "network:#{location.id}", "tag:#{tag.id}" ]
        expect(group).to be_valid
      end

      it 'fails validation with empty associated_resources' do
        group.associated_resources = []
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include("can't be blank")
      end

      it 'fails validation with nil associated_resources' do
        group.associated_resources = nil
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include("can't be blank")
      end

      it 'passes validation with blank values in associated_resources' do
        # Create test resources first
        router = create(:router_inventory, id: 123)
        location = create(:location_network, id: 456)

        group.associated_resources = [ "AP:123", "", "network:456", nil, "   " ]
        expect(group).to be_valid
        expect(group.associated_resources).to eq([ "AP:123", "network:456" ])
      end

      it 'fails validation with array containing only blank values' do
        group.associated_resources = [ "", nil, "   ", "\t", "\n" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include("can't be blank")
      end
    end

    context 'with invalid format' do
      it 'fails validation for invalid format' do
        group.associated_resources = [ "invalid_format" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include(
          "Invalid format: invalid_format. Expected format: 'AP:id', 'network:id', or 'tag:id'"
        )
      end

      it 'fails validation for missing ID' do
        group.associated_resources = [ "AP:" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include(
          "Invalid format: AP:. Expected format: 'AP:id', 'network:id', or 'tag:id'"
        )
      end

      it 'fails validation for unsupported type' do
        group.associated_resources = [ "unsupported:123" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include(
          "Invalid format: unsupported:123. Expected format: 'AP:id', 'network:id', or 'tag:id'"
        )
      end
    end

    context 'with non-existent resources' do
      it 'fails validation for non-existent router' do
        group.associated_resources = [ "AP:99999" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include(
          "AP with ID 99999 does not exist"
        )
      end

      it 'fails validation for non-existent location network' do
        group.associated_resources = [ "network:99999" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include(
          "network with ID 99999 does not exist"
        )
      end

      it 'fails validation for non-existent tag' do
        group.associated_resources = [ "tag:99999" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include(
          "tag with ID 99999 does not exist"
        )
      end

      it 'fails validation for multiple invalid resources' do
        group.associated_resources = [ "AP:99999", "network:88888", "tag:77777" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include(
          "AP with ID 99999 does not exist"
        )
        expect(group.errors[:associated_resources]).to include(
          "network with ID 88888 does not exist"
        )
        expect(group.errors[:associated_resources]).to include(
          "tag with ID 77777 does not exist"
        )
      end
    end

    context 'with mixed valid and invalid resources' do
      it 'fails validation for any invalid resource' do
        router = create(:router_inventory)
        group.associated_resources = [ "AP:#{router.id}", "network:99999" ]
        expect(group).not_to be_valid
        expect(group.errors[:associated_resources]).to include(
          "network with ID 99999 does not exist"
        )
      end
    end
  end
end
