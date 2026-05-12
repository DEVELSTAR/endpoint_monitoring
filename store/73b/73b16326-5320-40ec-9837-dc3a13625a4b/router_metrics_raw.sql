ATTACH TABLE _ UUID '7d9d7823-cfbd-4c2b-866c-24236367adad'
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
    `loss_pct` Decimal(18, 3),
    `http_status` Int32,
    `tcp_status` String,
    `status` UInt8 DEFAULT 1
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (ts, device_id, host)
TTL ts + toIntervalDay(7)
SETTINGS index_granularity = 8192
