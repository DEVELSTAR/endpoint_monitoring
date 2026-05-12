ATTACH TABLE _ UUID '76a2e6a3-1b0f-476b-b2ed-44315cce672a'
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
TTL ts + toIntervalYear(3)
SETTINGS index_granularity = 8192
