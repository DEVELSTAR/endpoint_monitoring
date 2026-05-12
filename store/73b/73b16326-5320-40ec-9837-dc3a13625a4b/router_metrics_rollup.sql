ATTACH TABLE _ UUID 'd2e40da6-b301-498a-97ef-448af2c7303b'
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
    `uplink_id` String,
    `uplink_type` String,
    `sum_latency` Float64,
    `sum_loss` Decimal(18, 3),
    `samples` UInt64,
    `good_count` UInt32 DEFAULT 0,
    `warning_count` UInt32 DEFAULT 0,
    `critical_count` UInt32 DEFAULT 0,
    `down_count` UInt32 DEFAULT 0
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (ts, device_id, host, endpoint_id, location_network_id, router_inventory_id, isp, org_id, uplink_id, uplink_type)
TTL ts + toIntervalDay(90)
SETTINGS index_granularity = 8192
