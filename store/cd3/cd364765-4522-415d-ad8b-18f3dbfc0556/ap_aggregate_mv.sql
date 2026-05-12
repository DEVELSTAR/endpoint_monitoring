ATTACH MATERIALIZED VIEW _ UUID '8547935f-1659-4a31-9c89-51d01b8bd602' TO default_test.ap_aggregate_data_mv
(
    `mac` String,
    `ln` UInt32,
    `d` Date,
    `h` UInt8,
    `tx_r_sum` Nullable(Float64),
    `tx_r_count` UInt64,
    `rx_r_sum` Nullable(Float64),
    `rx_r_count` UInt64,
    `tx_u_sum` Nullable(Float64),
    `rx_u_sum` Nullable(Float64),
    `voc_sum` Nullable(Float64),
    `voc_count` UInt64,
    `voc_min` Nullable(Float64),
    `voc_max` Nullable(Float64)
)
AS SELECT
    toString(info.NASID) AS mac,
    ln_id AS ln,
    toDate(toDateTime(created_at, 'UTC')) AS d,
    toHour(toDateTime(created_at, 'UTC')) AS h,
    sumOrNull(toFloat64OrZero(toString(u.TX_RATE))) AS tx_r_sum,
    countIf(toFloat64OrZero(toString(u.TX_RATE)) > 0) AS tx_r_count,
    sumOrNull(toFloat64OrZero(toString(u.RX_RATE))) AS rx_r_sum,
    countIf(toFloat64OrZero(toString(u.RX_RATE)) > 0) AS rx_r_count,
    sumOrNull(toFloat64OrZero(toString(u.TX_BYTES_INT))) AS tx_u_sum,
    sumOrNull(toFloat64OrZero(toString(u.RX_BYTES_INT))) AS rx_u_sum,
    sumOrNull(toFloat64OrZero(toString(sensor_data.AIR_DATA.VOC))) AS voc_sum,
    countIf(toFloat64OrZero(toString(sensor_data.AIR_DATA.VOC)) > 0) AS voc_count,
    minOrNull(toFloat64OrZero(toString(sensor_data.AIR_DATA.VOC))) AS voc_min,
    maxOrNull(toFloat64OrZero(toString(sensor_data.AIR_DATA.VOC))) AS voc_max
FROM default_test.monitoring_child
ARRAY JOIN ifNull(uplink, lan) AS u
GROUP BY
    mac,
    ln,
    d,
    h
