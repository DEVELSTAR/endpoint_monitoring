# frozen_string_literal: true

require "securerandom"
require "logger"

module EndpointMonitoring
  class GroupSeeder
    GROUP_SEED_USER_ID = nil
    GROUP_SEED_USER_TOKEN = "819228649674".freeze
    GROUP_COUNT = 250
    GROUP_TYPES = %w[network location router campus branch isp tag collection bundle region hub].freeze
    ICMP_TARGETS = %w[
      1.1.1.1
      8.8.8.8
      9.9.9.9
      208.67.222.222
      208.67.220.220
      8.8.4.4
      4.2.2.2
      114.114.114.114
      223.5.5.5
    ].freeze
    HTTP_TARGETS = %w[
      https://www.google.com
      https://www.cloudflare.com
      https://status.aws.amazon.com
      https://status.azure.com/en-us/status
      https://status.slack.com
      https://status.github.com
      https://status.atlassian.com
      https://status.zoom.us
      https://www.wikipedia.org
      https://news.ycombinator.com
      https://www.reddit.com
      https://stackexchange.com
    ].freeze
    TCP_TARGETS = [
      { name: "SMTP Google", host: "smtp.gmail.com", port: 587 },
      { name: "SSH Github", host: "github.com", port: 22 },
      { name: "Redis Cache", host: "redis.cache.internal", port: 6379 },
      { name: "MySQL Primary", host: "mysql.production.internal", port: 3306 },
      { name: "Postgres Reporting", host: "reports.db.internal", port: 5432 },
      { name: "NTP Pool", host: "pool.ntp.org", port: 123 },
      { name: "MQTT Broker", host: "mqtt.iot.internal", port: 1883 }
    ].freeze
    HTTP_RESPONSE_CODE_SETS = [
      [200],
      [200, 201],
      [200, 204],
      [200, 302],
      [200, 201, 204],
      [200, 202, 204],
      [200, 201, 202, 204]
    ].freeze

    attr_reader :user, :group_count, :router_ids, :network_ids, :tag_ids, :logger, :rng

    def self.build_from_env(group_count: nil, logger: Logger.new($stdout))
      default_count = GROUP_COUNT || 100
      count = (group_count || ENV["GROUP_COUNT"] || default_count).to_i
      raise ArgumentError, "GROUP_COUNT must be greater than zero" if count <= 0

      user = locate_user
      raise "Set GROUP_SEED_USER_ID or GROUP_SEED_USER_TOKEN to identify a user" unless user
      raise "Selected user #{user.id} does not have an organisation_id" unless user.organisation_id.present?

      router_ids = RouterInventory.pluck(:id)
      network_ids = LocationNetwork.pluck(:id)
      tag_ids = Tag.pluck(:id)

      missing = []
      missing << "RouterInventory (AP)" if router_ids.empty?
      missing << "LocationNetwork (network)" if network_ids.empty?
      missing << "Tag" if tag_ids.empty?
      raise "Associated resource data missing for: #{missing.join(', ')}. Create/import those records first." if missing.any?

      new(
        user: user,
        group_count: count,
        router_ids: router_ids,
        network_ids: network_ids,
        tag_ids: tag_ids,
        logger: logger
      )
    end

    def self.locate_user
      id_from_env = ENV["GROUP_SEED_USER_ID"]
      token_from_env = ENV["GROUP_SEED_USER_TOKEN"]

      if (id = id_from_env || GROUP_SEED_USER_ID).present?
        User.find_by(id: id)
      elsif (token = token_from_env || GROUP_SEED_USER_TOKEN).present?
        User.find_by(access_token: token)
      else
        User.order(:id).first
      end
    end

    def initialize(user:, group_count:, router_ids:, network_ids:, tag_ids:, logger: Logger.new($stdout))
      @user = user
      @group_count = group_count
      @router_ids = Array(router_ids)
      @network_ids = Array(network_ids)
      @tag_ids = Array(tag_ids)
      @logger = logger || Logger.new($stdout)
      @rng = Random.new
      @suffix_counter = 0
    end

    def run!
      log "Creating #{group_count} endpoint monitoring groups for user ##{user.id}"
      created = 0

      group_count.times do |index|
        begin
          create_group!(index)
          created += 1
        rescue StandardError => e
          log "Skipped group ##{index + 1}: #{e.message}"
        end
      end

      log "Finished seeding: #{created}/#{group_count} groups created successfully."
    end

    private

    def create_group!(index)
      group_name = build_group_name(index)

      EndpointMonitoringGroup.transaction do
        group = EndpointMonitoringGroup.new(
          name: group_name,
          group_type: GROUP_TYPES[index % GROUP_TYPES.size],
          user: user,
          organisation_id: user.organisation_id
        )

        group.associated_resources = build_associated_resources
        build_endpoint_payloads(index).each do |attrs|
          group.endpoint_monitoring_endpoints.build(attrs)
        end

        group.save!
      end

      log "Created group #{group_name}"
    end

    def build_group_name(index)
      prefix = %w[Core Backbone Edge Campus Branch Field Remote Transit TransitWest TransitEast
                  Aggregation Access Distribution NOC Region Cluster Segment Mesh Secure].sample(random: rng)
      "#{prefix} Group #{format('%03d', index + 1)}-#{unique_suffix}"
    end

    def build_associated_resources
      [
        format("AP:%<id>d", id: router_ids.sample(random: rng)),
        format("network:%<id>d", id: network_ids.sample(random: rng)),
        format("tag:%<id>d", id: tag_ids.sample(random: rng))
      ].uniq
    end

    def build_endpoint_payloads(index)
      [
        build_icmp_endpoint(index),
        build_http_endpoint(index),
        build_tcp_endpoint(index)
      ]
    end

    def build_icmp_endpoint(index)
      host = ICMP_TARGETS[index % ICMP_TARGETS.size]
      latency_warning = rng.rand(80..350)
      latency_critical = latency_warning + rng.rand(40..400)

      {
        name: "ICMP #{host} #{unique_suffix}",
        host: host,
        monitoring_mode: "icmp",
        latency_warning: latency_warning,
        latency_critical: latency_critical
      }
    end

    def build_http_endpoint(index)
      url = HTTP_TARGETS[index % HTTP_TARGETS.size]
      response_time = rng.rand(250..2500)

      {
        name: "HTTP #{URI.parse(url).host} #{unique_suffix}",
        host: url,
        monitoring_mode: "http",
        response_time: response_time,
        acceptable_response_codes: HTTP_RESPONSE_CODE_SETS.sample(random: rng)
      }
    rescue URI::InvalidURIError
      {
        name: "HTTP fallback #{unique_suffix}",
        host: "https://status.example.com",
        monitoring_mode: "http",
        response_time: rng.rand(250..2500),
        acceptable_response_codes: [200, 201, 204]
      }
    end

    def build_tcp_endpoint(index)
      target = TCP_TARGETS[index % TCP_TARGETS.size]

      {
        name: "TCP #{target[:name]} #{unique_suffix}",
        host: target[:host],
        monitoring_mode: "tcp",
        port: target[:port]
      }
    end

    def unique_suffix
      @suffix_counter += 1
      SecureRandom.alphanumeric(3).upcase
    end

    def log(message)
      logger&.info(message)
    rescue StandardError
      puts message
    end
  end
end

namespace :endpoint_monitoring do
  desc "Bulk create endpoint monitoring groups with endpoints and associated AP/network/tag mappings"
  task seed_groups: :environment do
    EndpointMonitoring::GroupSeeder.build_from_env.run!
  end
end
