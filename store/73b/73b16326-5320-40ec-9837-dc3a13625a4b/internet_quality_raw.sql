ATTACH TABLE _ UUID '848abc14-dd27-4d2e-a14c-bce875a69ba3'
(
    `ts` DateTime('UTC') DEFAULT now(),
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
    `tcp_status` String
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (ts, device_id, host)
TTL ts + toIntervalDay(7)
SETTINGS index_granularity = 8192
