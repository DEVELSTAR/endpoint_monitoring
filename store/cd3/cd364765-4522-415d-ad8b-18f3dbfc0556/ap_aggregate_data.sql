ATTACH TABLE _ UUID '0139a85a-5205-4c28-98c6-e7143a09d1a6'
(
    `mac` String,
    `ln` UInt32,
    `d` Date,
    `h` UInt8,
    `tx_r_sum` Float32,
    `tx_r_count` UInt32,
    `rx_r_sum` Float32,
    `rx_r_count` UInt32,
    `tx_u_sum` Float32,
    `rx_u_sum` Float32,
    `voc_sum` Float32,
    `voc_count` UInt32,
    `voc_min` Float32,
    `voc_max` Float32
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(d)
ORDER BY (mac, ln, d, h)
TTL d + toIntervalDay(730)
SETTINGS index_granularity = 8192
