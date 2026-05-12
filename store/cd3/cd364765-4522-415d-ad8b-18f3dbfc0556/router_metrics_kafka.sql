ATTACH TABLE _ UUID '7f93bc30-2eca-4b09-8006-488226338144'
(
    `ts` DateTime,
    `org_id` String,
    `endpoint_id` String,
    `host` String,
    `device_id` String,
    `isp` String,
    `region` String,
    `location_network_id` String,
    `router_inventory_id` String,
    `latitude` String,
    `longitude` String,
    `uplink_id` String,
    `uplink_type` String,
    `latency_ms` UInt32,
    `loss_pct` Float32,
    `http_status` UInt32,
    `tcp_status` String,
    `status` UInt8
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'localhost:9092', kafka_topic_list = 'endpoint-monitoring', kafka_group_name = 'endpoint-monitoring-group', kafka_format = 'JSONEachRow', kafka_num_consumers = 2, kafka_thread_per_consumer = 1, kafka_skip_broken_messages = 10
