class AddStatusToRouterMetricsKafkaAndMv < ActiveRecord::Migration[8.0]
  def up
    kafka_brokers = ENV.fetch("KAFKA_BROKERS", "127.0.0.1:9092")
    kafka_topic = ENV.fetch("KAFKA_ROUTER_METRICS_TOPIC", "endpoint-monitoring")
    kafka_group = ENV.fetch("KAFKA_ROUTER_METRICS_GROUP", "endpoint-monitoring-group")

    execute "DROP VIEW IF EXISTS router_metrics_kafka_mv"
    execute "DROP TABLE IF EXISTS router_metrics_kafka"

    execute <<~SQL
      CREATE TABLE router_metrics_kafka (
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
        tcp_status String,
        status UInt8
      ) ENGINE = Kafka
      SETTINGS kafka_broker_list = '#{kafka_brokers}',
               kafka_topic_list = '#{kafka_topic}',
               kafka_group_name = '#{kafka_group}',
               kafka_format = 'JSONEachRow',
               kafka_num_consumers = 2,
               kafka_thread_per_consumer = 1,
               kafka_skip_broken_messages = 10
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW router_metrics_kafka_mv TO router_metrics_raw AS
      SELECT
        ts, org_id, endpoint_id, host, device_id, isp, region,
        location_network_id, router_inventory_id, latitude, longitude,
        uplink_id, uplink_type, latency_ms, loss_pct, http_status,
        tcp_status, status
      FROM router_metrics_kafka
    SQL
  end

  def down
    kafka_brokers = ENV.fetch("KAFKA_BROKERS", "127.0.0.1:9092")
    kafka_topic = ENV.fetch("KAFKA_ROUTER_METRICS_TOPIC", "endpoint-monitoring")
    kafka_group = ENV.fetch("KAFKA_ROUTER_METRICS_GROUP", "endpoint-monitoring-group")

    execute "DROP VIEW IF EXISTS router_metrics_kafka_mv"
    execute "DROP TABLE IF EXISTS router_metrics_kafka"

    execute <<~SQL
      CREATE TABLE router_metrics_kafka (
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
      SETTINGS kafka_broker_list = '#{kafka_brokers}',
               kafka_topic_list = '#{kafka_topic}',
               kafka_group_name = '#{kafka_group}',
               kafka_format = 'JSONEachRow',
               kafka_num_consumers = 2,
               kafka_thread_per_consumer = 1,
               kafka_skip_broken_messages = 10
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW router_metrics_kafka_mv TO router_metrics_raw AS
      SELECT
        ts, org_id, endpoint_id, host, device_id, isp, region,
        location_network_id, router_inventory_id, latitude, longitude,
        uplink_id, uplink_type, latency_ms, loss_pct, http_status,
        tcp_status
      FROM router_metrics_kafka
    SQL
  end
end
