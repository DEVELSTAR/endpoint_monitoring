ATTACH MATERIALIZED VIEW _ UUID '7d128df7-669c-4211-98d9-adb562e7e69c' TO default.internet_quality_1h
(
    `ts` DateTime('UTC'),
    `org_id` String,
    `device_id` String,
    `uplink_id` String,
    `uplink_type` String,
    `sum_latency` Int64,
    `sum_loss` Float64,
    `samples` UInt64
)
AS SELECT
    toStartOfHour(ts) AS ts,
    org_id,
    device_id,
    uplink_id,
    uplink_type,
    sum(latency_ms) AS sum_latency,
    sum(loss_pct) AS sum_loss,
    count() AS samples
FROM default.internet_quality_raw
GROUP BY
    ts,
    org_id,
    device_id,
    uplink_id,
    uplink_type
