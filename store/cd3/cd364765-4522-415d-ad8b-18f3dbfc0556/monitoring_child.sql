ATTACH TABLE _ UUID 'ffe28cb9-dedd-4942-90be-e4c0c1ba16ef'
(
    `info` JSON CODEC(ZSTD(5)),
    `s_info` JSON CODEC(ZSTD(5)),
    `m_info` JSON CODEC(ZSTD(5)),
    `lan` JSON CODEC(ZSTD(5)),
    `sensor_data` JSON CODEC(ZSTD(5)),
    `uplink` Array(JSON) CODEC(ZSTD(5)),
    `ssids` Array(JSON) CODEC(ZSTD(5)),
    `clients` Array(JSON) CODEC(ZSTD(5)),
    `cmd_res` Array(JSON) CODEC(ZSTD(5)),
    `radio` Array(JSON) CODEC(ZSTD(5)),
    `sw_prt` Array(JSON) CODEC(ZSTD(5)),
    `created_at` DateTime CODEC(DoubleDelta, ZSTD(3)),
    `ln_id` UInt32 CODEC(T64, ZSTD(3)),
    `org_id` UInt32 CODEC(T64, ZSTD(3))
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(created_at)
ORDER BY (org_id, ln_id, created_at)
TTL created_at + toIntervalDay(730)
SETTINGS merge_max_block_size = 8192, max_bytes_to_merge_at_max_space_in_pool = 1073741824, ttl_only_drop_parts = 1, min_bytes_for_wide_part = 10485760, min_rows_for_wide_part = 1000000, async_insert = 1, index_granularity = 8192
