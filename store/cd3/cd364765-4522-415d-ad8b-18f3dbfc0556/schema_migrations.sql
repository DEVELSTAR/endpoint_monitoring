ATTACH TABLE _ UUID '842227c4-9c78-48c0-998e-c0acccd82d4c'
(
    `version` String,
    `active` Int8 DEFAULT 1,
    `ver` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(ver)
ORDER BY version
SETTINGS index_granularity = 8192
