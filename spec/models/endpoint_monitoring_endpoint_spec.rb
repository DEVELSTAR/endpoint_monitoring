require 'rails_helper'

RSpec.describe EndpointMonitoringEndpoint, type: :model do
  let(:group) { create(:endpoint_monitoring_group) }

  describe 'associations' do
    it 'belongs to endpoint_monitoring_group' do
      endpoint = described_class.new(endpoint_monitoring_group: nil)
      endpoint.valid?
      expect(endpoint.errors[:endpoint_monitoring_group]).to be_present
    end
  end

  describe 'constants' do
    it 'defines MONITORING_MODES' do
      expect(EndpointMonitoringEndpoint::MONITORING_MODES).to eq(%w[icmp tcp http])
    end
  end

  describe 'validations' do
    describe 'basic validations' do
      it 'validates presence of name' do
        endpoint = described_class.new(name: nil)
        endpoint.valid?
        expect(endpoint.errors[:name]).to include("can't be blank")
      end

      it 'validates presence of host' do
        endpoint = described_class.new(host: nil)
        endpoint.valid?
        expect(endpoint.errors[:host]).to include("can't be blank")
      end

      it 'validates inclusion of monitoring_mode with detailed message' do
        endpoint = described_class.new(monitoring_mode: 'invalid')
        endpoint.valid?
        expect(endpoint.errors[:monitoring_mode]).to include(
          "invalid is invalid. Allowed values: icmp, tcp, http"
        )
      end
    end
  end

  context 'mode-specific validations' do
    it 'is valid for ICMP mode with required fields' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'Google DNS',
        host: '8.8.8.8',
        monitoring_mode: 'icmp',
        latency_critical: 300,
        latency_warning: 200,
      )
      expect(endpoint).to be_valid
    end

    it 'is invalid for ICMP mode without latency_critical' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'Google DNS',
        host: '8.8.8.8',
        monitoring_mode: 'icmp'
      )
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:latency_critical]).to include("can't be blank")
    end

    it 'is valid for TCP mode with port and latency' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'SSH Server',
        host: 'example.com',
        monitoring_mode: 'tcp',
        port: 22,
        latency_critical: 400,
        latency_warning: 250
      )
      expect(endpoint).to be_valid
    end

    it 'is invalid for TCP mode without port' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'SSH Server',
        host: 'example.com',
        monitoring_mode: 'tcp'
      )
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:port]).to include("can't be blank")
    end

    it 'is valid for HTTP mode with response_time and codes' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'Example Website',
        host: 'https://example.com',
        monitoring_mode: 'http',
        response_time: 120,
        acceptable_response_codes: [ 200, 201 ]
      )
      expect(endpoint).to be_valid
    end

    it 'is invalid for HTTP mode without acceptable_response_codes' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'Example Website',
        host: 'https://example.com',
        monitoring_mode: 'http',
        response_time: 120
      )
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:acceptable_response_codes]).to include("can't be blank")
    end

    it 'is invalid for HTTP mode without http:// or https://' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'Example',
        host: 'example.com',
        monitoring_mode: 'http',
        response_time: 500,
        acceptable_response_codes: [ 200 ]
      )
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:host]).to include('example.com must be a valid URL with http:// or https://')
    end


    it 'is invalid with unknown monitoring mode' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'Unknown',
        host: '8.8.8.8',
        monitoring_mode: 'unknown'
      )
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:monitoring_mode]).to be_present
    end
  end

  describe 'numericality validations' do
    context 'for latency thresholds' do
      it 'is invalid with latency_critical <= 0' do
        endpoint = build(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'icmp',
                        latency_critical: 0)
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:latency_critical]).to be_present
      end

      it 'is invalid with latency_critical > 3000' do
        endpoint = build(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'icmp',
                        latency_critical: 3001)
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:latency_critical]).to be_present
      end

      it 'is invalid with latency_warning <= 0' do
        endpoint = build(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'icmp',
                        latency_warning: 0)
        expect(endpoint).not_to be_valid
      end

      it 'is invalid with latency_warning > 3000' do
        endpoint = build(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'icmp',
                        latency_warning: 3001)
        expect(endpoint).not_to be_valid
      end
    end

    context 'for port' do
      it 'is invalid with port <= 0' do
        endpoint = build(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'tcp',
                        port: 0)
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:port]).to be_present
      end

      it 'is invalid with port > 65535' do
        endpoint = build(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'tcp',
                        port: 65536)
        expect(endpoint).not_to be_valid
      end

      it 'is valid with port 1' do
        endpoint = build(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'tcp',
                        port: 1,
                        latency_critical: 500,
                        latency_warning: 300)
        expect(endpoint).to be_valid
      end

      it 'is valid with port 65535' do
        endpoint = build(:endpoint_monitoring_endpoint,
                        endpoint_monitoring_group: group,
                        monitoring_mode: 'tcp',
                        port: 65535,
                        latency_critical: 500,
                        latency_warning: 300)
        expect(endpoint).to be_valid
      end
    end
  end

  describe 'url_accessible validation' do
    it 'is valid with http URL' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'http',
                      host: 'http://example.com',
                      response_time: 500,
                      acceptable_response_codes: [ 200 ])
      expect(endpoint).to be_valid
    end

    it 'is valid with https URL' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'http',
                      host: 'https://example.com',
                      response_time: 500,
                      acceptable_response_codes: [ 200 ])
      expect(endpoint).to be_valid
    end

    it 'is invalid with ftp URL' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'http',
                      host: 'ftp://example.com',
                      response_time: 500,
                      acceptable_response_codes: [ 200 ])
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:host]).to include("ftp://example.com must be a valid URL with http:// or https://")
    end

    it 'is invalid without protocol' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'http',
                      host: 'example.com',
                      response_time: 500,
                      acceptable_response_codes: [ 200 ])
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:host]).to be_present
    end

    it 'is invalid without host part' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'http',
                      host: 'http://',
                      response_time: 500,
                      acceptable_response_codes: [ 200 ])
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:host]).to include("http:// must include a valid host")
    end

    it 'handles invalid URI format' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'http',
                      host: 'http://[invalid',
                      response_time: 500,
                      acceptable_response_codes: [ 200 ])
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:host]).to include("http://[invalid is not a valid host")
    end

    it 'is valid with URL path' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'http',
                      host: 'https://example.com/api/v1/test',
                      response_time: 500,
                      acceptable_response_codes: [ 200 ])
      expect(endpoint).to be_valid
    end

    it 'is valid with query parameters' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'http',
                      host: 'https://example.com?param=value',
                      response_time: 500,
                      acceptable_response_codes: [ 200 ])
      expect(endpoint).to be_valid
    end

    it 'does not validate URL for non-HTTP modes' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'icmp',
                      host: 'not-a-url',
                      latency_critical: 300,
                      latency_warning: 200)
      expect(endpoint).not_to be_valid
    end
  end

  describe 'edge cases' do
    it 'is valid with all optional fields set' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: group,
                      monitoring_mode: 'icmp',
                      name: 'Test',
                      host: '8.8.8.8',
                      latency_critical: 300,
                      latency_warning: 200,
                      port: nil)
      expect(endpoint).to be_valid
    end

    it 'requires endpoint_monitoring_group' do
      endpoint = build(:endpoint_monitoring_endpoint,
                      endpoint_monitoring_group: nil,
                      monitoring_mode: 'icmp')
      expect(endpoint).not_to be_valid
    end

    it 'allows blank host for testing' do
      endpoint = described_class.new(
        endpoint_monitoring_group: group,
        name: 'Test',
        host: '',
        monitoring_mode: 'icmp'
      )
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:host]).to include("can't be blank")
    end
  end
end
