ATTACH MATERIALIZED VIEW _ UUID 'ea898948-2c20-430e-8cb9-4b8ca351a766' TO default_test.internet_quality_1d
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
    toStartOfDay(ts) AS ts,
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
