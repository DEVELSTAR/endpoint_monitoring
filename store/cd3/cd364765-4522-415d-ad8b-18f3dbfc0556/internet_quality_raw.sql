ATTACH TABLE _ UUID '49f27879-305a-4cf0-a50b-f552765af540'
(
    `ts` DateTime DEFAULT now(),
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
    `tcp_status` String
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (ts, device_id, host)
TTL ts + toIntervalDay(7)
SETTINGS index_granularity = 8192
