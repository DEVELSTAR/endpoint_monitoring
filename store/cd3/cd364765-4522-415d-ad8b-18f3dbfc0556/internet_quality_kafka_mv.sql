ATTACH MATERIALIZED VIEW _ UUID 'db3c22c6-d84c-4623-952b-6e2664042f90' TO default_test.internet_quality_raw
(
    `ts` DateTime,
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
    `latency_ms` UInt32,
    `loss_pct` Float32,
    `http_status` UInt32,
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
FROM default_test.internet_quality_kafka
