ATTACH TABLE _ UUID 'fecc5ed8-c84a-4f93-96c1-be6d806b0338'
(
    `ts` DateTime('UTC'),
    `org_id` String,
    `device_id` String,
    `uplink_id` String,
    `uplink_type` String,
    `sum_latency` Float64,
    `sum_loss` Decimal(18, 3),
    `samples` UInt64
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (ts, org_id, device_id, uplink_id, uplink_type)
TTL ts + toIntervalDay(400)
SETTINGS index_granularity = 8192
