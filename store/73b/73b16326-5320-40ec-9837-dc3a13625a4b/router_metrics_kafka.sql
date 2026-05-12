ATTACH TABLE _ UUID '16becca1-504b-47d7-88cc-82ab4a7bfacc'
(
    `ts` DateTime('UTC'),
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
    `latency_ms` Int32,
    `loss_pct` Float32,
    `http_status` Int32,
    `tcp_status` String,
    `status` UInt8
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'localhost:9092', kafka_topic_list = 'endpoint-monitoring', kafka_group_name = 'endpoint-monitoring-group', kafka_format = 'JSONEachRow', kafka_num_consumers = 2, kafka_thread_per_consumer = 1, kafka_skip_broken_messages = 10
