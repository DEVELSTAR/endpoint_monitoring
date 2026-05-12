ATTACH TABLE _ UUID 'a4a1ba64-c1e2-4ff7-b8f4-a6fba5f7ce43'
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
    `loss_pct` Decimal(18, 3),
    `http_status` UInt32,
    `tcp_status` String,
    `status` UInt8 DEFAULT 1
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (ts, device_id, host)
TTL ts + toIntervalDay(7)
SETTINGS index_granularity = 8192
