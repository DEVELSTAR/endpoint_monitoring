ATTACH TABLE _ UUID '959a02c5-84cf-45d8-9ce0-e3394f675d7f'
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
