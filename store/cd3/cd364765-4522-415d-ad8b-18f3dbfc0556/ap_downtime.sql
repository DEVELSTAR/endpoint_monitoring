ATTACH TABLE _ UUID '4d2c4f88-7a3a-4f95-904f-a9843f141548'
(
    `mac` String,
    `st` DateTime CODEC(DoubleDelta, ZSTD(3)),
    `et` DateTime CODEC(DoubleDelta, ZSTD(3)),
    `sec` UInt32 CODEC(T64, ZSTD(3))
)
ENGINE = MergeTree
ORDER BY (mac, st)
TTL st + toIntervalDay(730)
SETTINGS merge_max_block_size = 8192, ttl_only_drop_parts = 1, async_insert = 1, index_granularity = 8192
