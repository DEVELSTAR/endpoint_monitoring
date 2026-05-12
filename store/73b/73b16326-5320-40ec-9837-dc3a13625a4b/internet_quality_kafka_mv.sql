ATTACH MATERIALIZED VIEW _ UUID '0d2276ed-9e79-45ff-a14d-f759c4053525' TO default.internet_quality_raw
(
    `ts` DateTime('UTC'),
    `org_id` String,
    `endpoint_id` String,
    `host` String,
    `device_id` String,
    `isp` String,
    `region` String,
    `location_network_id` String,
    `router_inventory_id` String,
    `latitude` String,
    `longitude` String,
    `uplink_id` String,
    `uplink_type` String,
    `latency_ms` Int32,
    `loss_pct` Float32,
    `http_status` Int32,
    `tcp_status` String
)
AS SELECT
    ts,
    org_id,
    endpoint_id,
    host,
    device_id,
    isp,
    region,
    location_network_id,
    router_inventory_id,
    latitude,
    longitude,
    uplink_id,
    uplink_type,
    latency_ms,
    loss_pct,
    http_status,
    tcp_status
FROM default.internet_quality_kafka
