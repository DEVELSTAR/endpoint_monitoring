ATTACH MATERIALIZED VIEW _ UUID '9c1de480-ddef-4724-b530-ca7e2b26fd0b' TO default_test.internet_quality_1h
(
    `ts` DateTime,
    `org_id` String,
    `device_id` String,
    `uplink_id` String,
    `uplink_type` String,
    `sum_latency` UInt64,
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
FROM default_test.internet_quality_raw
GROUP BY
    ts,
    org_id,
    device_id,
    uplink_id,
    uplink_type
