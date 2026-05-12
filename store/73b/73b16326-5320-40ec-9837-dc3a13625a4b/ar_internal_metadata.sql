ATTACH TABLE _ UUID 'db0cfaa3-0ba7-460b-a6ba-1ac118fb0f33'
(
    `key` String,
    `value` Nullable(String),
    `created_at` DateTime,
    `updated_at` DateTime
)
ENGINE = ReplacingMergeTree(created_at)
PARTITION BY key
ORDER BY key
SETTINGS index_granularity = 8192
