ATTACH MATERIALIZED VIEW _ UUID '3a985faf-89a4-477b-bc3f-548a48df72a5' TO default_test.internet_quality_5m
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
    toStartOfInterval(ts, toIntervalMinute(5)) AS ts,
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
