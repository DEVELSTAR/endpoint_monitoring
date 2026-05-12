ATTACH TABLE _ UUID '087e63d3-a19b-461b-b411-6c06f0a6f497'
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
TTL ts + toIntervalDay(400)
SETTINGS index_granularity = 8192
