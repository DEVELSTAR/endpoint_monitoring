ATTACH MATERIALIZED VIEW _ UUID '320ba4d8-1d0c-472d-a7fa-5c00de3edbf4' TO default.internet_quality_5m
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
    toStartOfInterval(ts, toIntervalMinute(5)) AS ts,
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
