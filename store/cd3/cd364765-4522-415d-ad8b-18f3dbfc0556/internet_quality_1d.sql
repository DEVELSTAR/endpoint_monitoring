ATTACH TABLE _ UUID 'd3216f3e-9902-4cee-886b-0df26f2db7a7'
(
    `ts` DateTime,
    `org_id` String,
    `device_id` String,
    `uplink_id` String,
    `uplink_type` String,
    `sum_latency` Float32,
    `sum_loss` Decimal(18, 3),
    `samples` UInt64
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (ts, org_id, device_id, uplink_id, uplink_type)
TTL ts + toIntervalYear(3)
SETTINGS index_granularity = 8192
