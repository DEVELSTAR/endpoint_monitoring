# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_12_124415) do
  # TABLE: internet_quality_1d
  # SQL: CREATE TABLE internet_quality_1d ( `ts` DateTime('UTC'), `org_id` String, `device_id` String, `uplink_id` String, `uplink_type` String, `sum_latency` Float64, `sum_loss` Decimal(18, 3), `samples` UInt64 ) ENGINE = SummingMergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, org_id, device_id, uplink_id, uplink_type) TTL ts + toIntervalYear(3) SETTINGS index_granularity = 8192
  create_table "internet_quality_1d", id: false, options: "SummingMergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, org_id, device_id, uplink_id, uplink_type) TTL ts + toIntervalYear(3) SETTINGS index_granularity = 8192", force: :cascade do |t|
    t.datetime "ts", precision: nil, null: false
    t.string "org_id", null: false
    t.string "device_id", null: false
    t.string "uplink_id", null: false
    t.string "uplink_type", null: false
    t.float "sum_latency", null: false
    t.decimal "sum_loss", precision: 18, scale: 3, null: false
    t.integer "samples", limit: 8, null: false
  end

  # TABLE: internet_quality_1h
  # SQL: CREATE TABLE internet_quality_1h ( `ts` DateTime('UTC'), `org_id` String, `device_id` String, `uplink_id` String, `uplink_type` String, `sum_latency` Float64, `sum_loss` Decimal(18, 3), `samples` UInt64 ) ENGINE = SummingMergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, org_id, device_id, uplink_id, uplink_type) TTL ts + toIntervalDay(400) SETTINGS index_granularity = 8192
  create_table "internet_quality_1h", id: false, options: "SummingMergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, org_id, device_id, uplink_id, uplink_type) TTL ts + toIntervalDay(400) SETTINGS index_granularity = 8192", force: :cascade do |t|
    t.datetime "ts", precision: nil, null: false
    t.string "org_id", null: false
    t.string "device_id", null: false
    t.string "uplink_id", null: false
    t.string "uplink_type", null: false
    t.float "sum_latency", null: false
    t.decimal "sum_loss", precision: 18, scale: 3, null: false
    t.integer "samples", limit: 8, null: false
  end

  # TABLE: internet_quality_5m
  # SQL: CREATE TABLE internet_quality_5m ( `ts` DateTime('UTC'), `org_id` String, `device_id` String, `uplink_id` String, `uplink_type` String, `sum_latency` Float64, `sum_loss` Decimal(18, 3), `samples` UInt64 ) ENGINE = SummingMergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, org_id, device_id, uplink_id, uplink_type) TTL ts + toIntervalDay(35) SETTINGS index_granularity = 8192
  create_table "internet_quality_5m", id: false, options: "SummingMergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, org_id, device_id, uplink_id, uplink_type) TTL ts + toIntervalDay(35) SETTINGS index_granularity = 8192", force: :cascade do |t|
    t.datetime "ts", precision: nil, null: false
    t.string "org_id", null: false
    t.string "device_id", null: false
    t.string "uplink_id", null: false
    t.string "uplink_type", null: false
    t.float "sum_latency", null: false
    t.decimal "sum_loss", precision: 18, scale: 3, null: false
    t.integer "samples", limit: 8, null: false
  end

  # TABLE: internet_quality_kafka
  # SQL: CREATE TABLE internet_quality_kafka ( `ts` DateTime('UTC'), `org_id` String, `endpoint_id` String, `host` String, `device_id` String, `isp` String, `region` String, `location_network_id` String, `router_inventory_id` String, `latitude` String, `longitude` String, `uplink_id` String, `uplink_type` String, `latency_ms` Int32, `loss_pct` Float32, `http_status` Int32, `tcp_status` String ) ENGINE = Kafka SETTINGS kafka_broker_list = 'kafka:9092', kafka_topic_list = 'internet-quality', kafka_group_name = 'internet-quality-group', kafka_format = 'JSONEachRow', kafka_num_consumers = 2, kafka_thread_per_consumer = 1, kafka_skip_broken_messages = 10
  create_table "internet_quality_kafka", id: false, options: "Kafka SETTINGS kafka_broker_list = 'kafka:9092', kafka_topic_list = 'internet-quality', kafka_group_name = 'internet-quality-group', kafka_format = 'JSONEachRow', kafka_num_consumers = 2, kafka_thread_per_consumer = 1, kafka_skip_broken_messages = 10", force: :cascade do |t|
    t.datetime "ts", precision: nil, null: false
    t.string "org_id", null: false
    t.string "endpoint_id", null: false
    t.string "host", null: false
    t.string "device_id", null: false
    t.string "isp", null: false
    t.string "region", null: false
    t.string "location_network_id", null: false
    t.string "router_inventory_id", null: false
    t.string "latitude", null: false
    t.string "longitude", null: false
    t.string "uplink_id", null: false
    t.string "uplink_type", null: false
    t.integer "latency_ms", unsigned: false, null: false
    t.float "loss_pct", null: false
    t.integer "http_status", unsigned: false, null: false
    t.string "tcp_status", null: false
  end

  # TABLE: internet_quality_raw
  # SQL: CREATE TABLE internet_quality_raw ( `ts` DateTime('UTC') DEFAULT now(), `org_id` String, `endpoint_id` String, `host` String, `device_id` String, `isp` String, `region` String, `location_network_id` String, `router_inventory_id` String, `latitude` String, `longitude` String, `uplink_id` String, `uplink_type` String, `latency_ms` Int32, `loss_pct` Float32, `http_status` Int32, `tcp_status` String ) ENGINE = MergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, device_id, host) TTL ts + toIntervalDay(7) SETTINGS index_granularity = 8192
  create_table "internet_quality_raw", id: false, options: "MergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, device_id, host) TTL ts + toIntervalDay(7) SETTINGS index_granularity = 8192", force: :cascade do |t|
    t.datetime "ts", precision: nil, default: -> { "now()" }, null: false
    t.string "org_id", null: false
    t.string "endpoint_id", null: false
    t.string "host", null: false
    t.string "device_id", null: false
    t.string "isp", null: false
    t.string "region", null: false
    t.string "location_network_id", null: false
    t.string "router_inventory_id", null: false
    t.string "latitude", null: false
    t.string "longitude", null: false
    t.string "uplink_id", null: false
    t.string "uplink_type", null: false
    t.integer "latency_ms", unsigned: false, null: false
    t.float "loss_pct", null: false
    t.integer "http_status", unsigned: false, null: false
    t.string "tcp_status", null: false
  end

  # TABLE: router_metrics_kafka
  # SQL: CREATE TABLE router_metrics_kafka ( `ts` DateTime('UTC'), `org_id` String, `endpoint_id` String, `host` String, `device_id` String, `isp` String, `region` String, `location_network_id` String, `router_inventory_id` String, `latitude` String, `longitude` String, `uplink_id` String, `uplink_type` String, `latency_ms` Int32, `loss_pct` Float32, `http_status` Int32, `tcp_status` String, `status` UInt8 ) ENGINE = Kafka SETTINGS kafka_broker_list = 'kafka:9092', kafka_topic_list = 'endpoint-monitoring', kafka_group_name = 'endpoint-monitoring-group', kafka_format = 'JSONEachRow', kafka_num_consumers = 2, kafka_thread_per_consumer = 1, kafka_skip_broken_messages = 10
  create_table "router_metrics_kafka", id: false, options: "Kafka SETTINGS kafka_broker_list = 'kafka:9092', kafka_topic_list = 'endpoint-monitoring', kafka_group_name = 'endpoint-monitoring-group', kafka_format = 'JSONEachRow', kafka_num_consumers = 2, kafka_thread_per_consumer = 1, kafka_skip_broken_messages = 10", force: :cascade do |t|
    t.datetime "ts", precision: nil, null: false
    t.string "org_id", null: false
    t.string "endpoint_id", null: false
    t.string "host", null: false
    t.string "device_id", null: false
    t.string "isp", null: false
    t.string "region", null: false
    t.string "location_network_id", null: false
    t.string "router_inventory_id", null: false
    t.string "latitude", null: false
    t.string "longitude", null: false
    t.string "uplink_id", null: false
    t.string "uplink_type", null: false
    t.integer "latency_ms", unsigned: false, null: false
    t.float "loss_pct", null: false
    t.integer "http_status", unsigned: false, null: false
    t.string "tcp_status", null: false
    t.integer "status", limit: 1, null: false
  end

  # TABLE: router_metrics_raw
  # SQL: CREATE TABLE router_metrics_raw ( `ts` DateTime('UTC') DEFAULT now(), `org_id` String, `endpoint_id` String, `host` String, `device_id` String, `isp` String, `region` String, `location_network_id` String, `router_inventory_id` String, `latitude` String, `longitude` String, `uplink_id` String, `uplink_type` String, `latency_ms` Int32, `loss_pct` Decimal(18, 3), `http_status` Int32, `tcp_status` String, `status` UInt8 DEFAULT 1 ) ENGINE = MergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, device_id, host) TTL ts + toIntervalDay(7) SETTINGS index_granularity = 8192
  create_table "router_metrics_raw", id: false, options: "MergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, device_id, host) TTL ts + toIntervalDay(7) SETTINGS index_granularity = 8192", force: :cascade do |t|
    t.datetime "ts", precision: nil, default: -> { "now()" }, null: false
    t.string "org_id", null: false
    t.string "endpoint_id", null: false
    t.string "host", null: false
    t.string "device_id", null: false
    t.string "isp", null: false
    t.string "region", null: false
    t.string "location_network_id", null: false
    t.string "router_inventory_id", null: false
    t.string "latitude", null: false
    t.string "longitude", null: false
    t.string "uplink_id", null: false
    t.string "uplink_type", null: false
    t.integer "latency_ms", unsigned: false, null: false
    t.decimal "loss_pct", precision: 18, scale: 3, null: false
    t.integer "http_status", unsigned: false, null: false
    t.string "tcp_status", null: false
    t.integer "status", limit: 1, default: 1, null: false
  end

  # TABLE: router_metrics_rollup
  # SQL: CREATE TABLE router_metrics_rollup ( `ts` DateTime('UTC') DEFAULT now(), `org_id` String, `endpoint_id` String, `host` String, `device_id` String, `isp` String, `region` String, `location_network_id` String, `router_inventory_id` String, `uplink_id` String, `uplink_type` String, `sum_latency` Float64, `sum_loss` Decimal(18, 3), `samples` UInt64, `good_count` UInt32 DEFAULT 0, `warning_count` UInt32 DEFAULT 0, `critical_count` UInt32 DEFAULT 0, `down_count` UInt32 DEFAULT 0 ) ENGINE = SummingMergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, device_id, host, endpoint_id, location_network_id, router_inventory_id, isp, org_id, uplink_id, uplink_type) TTL ts + toIntervalDay(90) SETTINGS index_granularity = 8192
  create_table "router_metrics_rollup", id: false, options: "SummingMergeTree PARTITION BY toYYYYMM(ts) ORDER BY (ts, device_id, host, endpoint_id, location_network_id, router_inventory_id, isp, org_id, uplink_id, uplink_type) TTL ts + toIntervalDay(90) SETTINGS index_granularity = 8192", force: :cascade do |t|
    t.datetime "ts", precision: nil, default: -> { "now()" }, null: false
    t.string "org_id", null: false
    t.string "endpoint_id", null: false
    t.string "host", null: false
    t.string "device_id", null: false
    t.string "isp", null: false
    t.string "region", null: false
    t.string "location_network_id", null: false
    t.string "router_inventory_id", null: false
    t.string "uplink_id", null: false
    t.string "uplink_type", null: false
    t.float "sum_latency", null: false
    t.decimal "sum_loss", precision: 18, scale: 3, null: false
    t.integer "samples", limit: 8, null: false
    t.integer "good_count", default: 0, null: false
    t.integer "warning_count", default: 0, null: false
    t.integer "critical_count", default: 0, null: false
    t.integer "down_count", default: 0, null: false
  end

  # TABLE: internet_quality_1d_mv
  # SQL: CREATE MATERIALIZED VIEW internet_quality_1d_mv TO internet_quality_1d ( `ts` DateTime('UTC'), `org_id` String, `device_id` String, `uplink_id` String, `uplink_type` String, `sum_latency` Int64, `sum_loss` Float64, `samples` UInt64 ) AS SELECT toStartOfDay(ts) AS ts, org_id, device_id, uplink_id, uplink_type, sum(latency_ms) AS sum_latency, sum(loss_pct) AS sum_loss, count() AS samples FROM internet_quality_raw GROUP BY ts, org_id, device_id, uplink_id, uplink_type
  create_table "internet_quality_1d_mv", view: true, materialized: true, to: "internet_quality_1d", id: false, as: "SELECT toStartOfDay(ts) AS ts, org_id, device_id, uplink_id, uplink_type, sum(latency_ms) AS sum_latency, sum(loss_pct) AS sum_loss, count() AS samples FROM internet_quality_raw GROUP BY ts, org_id, device_id, uplink_id, uplink_type", force: :cascade do |t|
  end

  # TABLE: internet_quality_1h_mv
  # SQL: CREATE MATERIALIZED VIEW internet_quality_1h_mv TO internet_quality_1h ( `ts` DateTime('UTC'), `org_id` String, `device_id` String, `uplink_id` String, `uplink_type` String, `sum_latency` Int64, `sum_loss` Float64, `samples` UInt64 ) AS SELECT toStartOfHour(ts) AS ts, org_id, device_id, uplink_id, uplink_type, sum(latency_ms) AS sum_latency, sum(loss_pct) AS sum_loss, count() AS samples FROM internet_quality_raw GROUP BY ts, org_id, device_id, uplink_id, uplink_type
  create_table "internet_quality_1h_mv", view: true, materialized: true, to: "internet_quality_1h", id: false, as: "SELECT toStartOfHour(ts) AS ts, org_id, device_id, uplink_id, uplink_type, sum(latency_ms) AS sum_latency, sum(loss_pct) AS sum_loss, count() AS samples FROM internet_quality_raw GROUP BY ts, org_id, device_id, uplink_id, uplink_type", force: :cascade do |t|
  end

  # TABLE: internet_quality_5m_mv
  # SQL: CREATE MATERIALIZED VIEW internet_quality_5m_mv TO internet_quality_5m ( `ts` DateTime('UTC'), `org_id` String, `device_id` String, `uplink_id` String, `uplink_type` String, `sum_latency` Int64, `sum_loss` Float64, `samples` UInt64 ) AS SELECT toStartOfInterval(ts, toIntervalMinute(5)) AS ts, org_id, device_id, uplink_id, uplink_type, sum(latency_ms) AS sum_latency, sum(loss_pct) AS sum_loss, count() AS samples FROM internet_quality_raw GROUP BY ts, org_id, device_id, uplink_id, uplink_type
  create_table "internet_quality_5m_mv", view: true, materialized: true, to: "internet_quality_5m", id: false, as: "SELECT toStartOfInterval(ts, toIntervalMinute(5)) AS ts, org_id, device_id, uplink_id, uplink_type, sum(latency_ms) AS sum_latency, sum(loss_pct) AS sum_loss, count() AS samples FROM internet_quality_raw GROUP BY ts, org_id, device_id, uplink_id, uplink_type", force: :cascade do |t|
  end

  # TABLE: internet_quality_kafka_mv
  # SQL: CREATE MATERIALIZED VIEW internet_quality_kafka_mv TO internet_quality_raw ( `ts` DateTime('UTC'), `org_id` String, `endpoint_id` String, `host` String, `device_id` String, `isp` String, `region` String, `location_network_id` String, `router_inventory_id` String, `latitude` String, `longitude` String, `uplink_id` String, `uplink_type` String, `latency_ms` Int32, `loss_pct` Float32, `http_status` Int32, `tcp_status` String ) AS SELECT ts, org_id, endpoint_id, host, device_id, isp, region, location_network_id, router_inventory_id, latitude, longitude, uplink_id, uplink_type, latency_ms, loss_pct, http_status, tcp_status FROM internet_quality_kafka
  create_table "internet_quality_kafka_mv", view: true, materialized: true, to: "internet_quality_raw", id: false, as: "SELECT ts, org_id, endpoint_id, host, device_id, isp, region, location_network_id, router_inventory_id, latitude, longitude, uplink_id, uplink_type, latency_ms, loss_pct, http_status, tcp_status FROM internet_quality_kafka", force: :cascade do |t|
  end

  # TABLE: router_metrics_kafka_mv
  # SQL: CREATE MATERIALIZED VIEW router_metrics_kafka_mv TO router_metrics_raw ( `ts` DateTime('UTC'), `org_id` String, `endpoint_id` String, `host` String, `device_id` String, `isp` String, `region` String, `location_network_id` String, `router_inventory_id` String, `latitude` String, `longitude` String, `uplink_id` String, `uplink_type` String, `latency_ms` Int32, `loss_pct` Float32, `http_status` Int32, `tcp_status` String, `status` UInt8 ) AS SELECT ts, org_id, endpoint_id, host, device_id, isp, region, location_network_id, router_inventory_id, latitude, longitude, uplink_id, uplink_type, latency_ms, loss_pct, http_status, tcp_status, status FROM router_metrics_kafka
  create_table "router_metrics_kafka_mv", view: true, materialized: true, to: "router_metrics_raw", id: false, as: "SELECT ts, org_id, endpoint_id, host, device_id, isp, region, location_network_id, router_inventory_id, latitude, longitude, uplink_id, uplink_type, latency_ms, loss_pct, http_status, tcp_status, status FROM router_metrics_kafka", force: :cascade do |t|
  end

  # TABLE: router_metrics_rollup_mv
  # SQL: CREATE MATERIALIZED VIEW router_metrics_rollup_mv TO router_metrics_rollup ( `ts` DateTime('UTC'), `org_id` String, `endpoint_id` String, `host` String, `device_id` String, `isp` String, `region` String, `location_network_id` String, `router_inventory_id` String, `uplink_id` String, `uplink_type` String, `sum_latency` Int64, `sum_loss` Decimal(38, 3), `good_count` UInt64, `warning_count` UInt64, `critical_count` UInt64, `down_count` UInt64, `samples` UInt64 ) AS SELECT toStartOfInterval(ts, toIntervalMinute(5)) AS ts, org_id, endpoint_id, host, device_id, isp, region, location_network_id, router_inventory_id, uplink_id, uplink_type, sum(latency_ms) AS sum_latency, sum(loss_pct) AS sum_loss, countIf(status = 1) AS good_count, countIf(status = 2) AS warning_count, countIf(status = 3) AS critical_count, countIf(status = 4) AS down_count, count() AS samples FROM router_metrics_raw GROUP BY ts, device_id, host, endpoint_id, region, location_network_id, router_inventory_id, isp, org_id, uplink_id, uplink_type
  create_table "router_metrics_rollup_mv", view: true, materialized: true, to: "router_metrics_rollup", id: false, as: "SELECT toStartOfInterval(ts, toIntervalMinute(5)) AS ts, org_id, endpoint_id, host, device_id, isp, region, location_network_id, router_inventory_id, uplink_id, uplink_type, sum(latency_ms) AS sum_latency, sum(loss_pct) AS sum_loss, countIf(status = 1) AS good_count, countIf(status = 2) AS warning_count, countIf(status = 3) AS critical_count, countIf(status = 4) AS down_count, count() AS samples FROM router_metrics_raw GROUP BY ts, device_id, host, endpoint_id, region, location_network_id, router_inventory_id, isp, org_id, uplink_id, uplink_type", force: :cascade do |t|
  end

end
