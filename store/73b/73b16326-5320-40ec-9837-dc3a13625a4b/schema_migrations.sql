ATTACH TABLE _ UUID '16b50139-6a25-41c5-953c-20577e09e9e2'
(
    `version` String,
    `active` Int8 DEFAULT 1,
    `ver` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(ver)
ORDER BY version
SETTINGS index_granularity = 8192
