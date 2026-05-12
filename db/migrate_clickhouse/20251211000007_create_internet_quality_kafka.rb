# frozen_string_literal: true

class CreateInternetQualityKafka < ActiveRecord::Migration[8.0]
  def up
    kafka_brokers = ENV.fetch("KAFKA_BROKERS", "127.0.0.1:9092")
    kafka_topic = ENV.fetch("KAFKA_INTERNET_QUALITY_TOPIC", "internet-quality")
    kafka_group = ENV.fetch("KAFKA_INTERNET_QUALITY_GROUP", "internet-quality-group")

    execute <<~SQL
      CREATE TABLE IF NOT EXISTS internet_quality_kafka (
        ts DateTime('UTC'),
        org_id String,
        endpoint_id String,
        host String,
        device_id String,
        isp String,
        region String,
        location_network_id String,
        router_inventory_id String,
        latitude String,
        longitude String,
        uplink_id String,
        uplink_type String,
        latency_ms Int32,
        loss_pct Float32,
        http_status Int32,
        tcp_status String
      ) ENGINE = Kafka
      SETTINGS
        kafka_broker_list = '#{kafka_brokers}',
        kafka_topic_list = '#{kafka_topic}',
        kafka_group_name = '#{kafka_group}',
        kafka_format = 'JSONEachRow',
        kafka_num_consumers = 2,
        kafka_thread_per_consumer = 1,
        kafka_skip_broken_messages = 10
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS internet_quality_kafka"
  end
end
