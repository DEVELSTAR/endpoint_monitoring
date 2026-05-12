ATTACH TABLE _ UUID 'b2a2cac8-9b6a-4b58-8ad0-92cfa13f7084'
(
    `ts` DateTime('UTC') DEFAULT now(),
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
ENGINE = MergeTree
ORDER BY (ts, device_id, host)
SETTINGS index_granularity = 8192
