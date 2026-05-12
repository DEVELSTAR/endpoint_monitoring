ATTACH TABLE _ UUID '59706035-c01f-407d-99fb-18bbce274a23'
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
TTL ts + toIntervalDay(35)
SETTINGS index_granularity = 8192
