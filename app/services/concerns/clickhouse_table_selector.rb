# app/services/concerns/clickhouse_table_selector.rb
# Module to determine which ClickHouse table to use based on time range
# Rule: >= 2880 minutes OR data older than 7 days = rollup, < 2880 minutes = raw
module ClickhouseTableSelector
  extend ActiveSupport::Concern
  include UtcTimeParser

  private

  def select_table(start_time, end_time)
    start_time = parse_time_utc(start_time)

    return :rollup if start_time > 48.hours.ago.utc

    :raw
  end

  # Helper to build queries that work with both raw and rollup tables
  # Returns hash with table-specific column expressions
  def table_columns(table_type)
    if table_type == :rollup
      {
        table: "router_metrics_rollup",
        ts_column: "ts",
        avg_latency: "sum(sum_latency) / sum(samples)",
        sample_count: "sum(samples)",
        good_count: "sum(good_count)",
        warning_count: "sum(warning_count)",
        critical_count: "sum(critical_count)",
        down_count: "sum(down_count)",
        # Column mappings for new schema
        device_id: "device_id",
        host: "host",
        endpoint_id: "endpoint_id",
        region: "region",
        location_network_id: "location_network_id",
        router_inventory_id: "router_inventory_id",
        isp: "isp",
        org_id: "org_id",
        # New uplink columns
        uplink_id: "uplink_id",
        uplink_type: "uplink_type"
      }
    else
      {
        table: "router_metrics_raw",
        ts_column: "ts",
        avg_latency: "avg(latency_ms)",
        sample_count: "count(*)",
        good_count: "countIf(status = 1)",
        warning_count: "countIf(status = 2)",
        critical_count: "countIf(status = 3)",
        down_count: "countIf(status = 4)",
        # Column mappings for new schema
        device_id: "device_id",
        host: "host",
        endpoint_id: "endpoint_id",
        region: "region",
        location_network_id: "location_network_id",
        router_inventory_id: "router_inventory_id",
        isp: "isp",
        org_id: "org_id",
        # Raw table specific columns
        latency_ms: "latency_ms",
        http_status: "http_status",
        tcp_status: "tcp_status",
        uplink: "uplink",
        latitude: "latitude",
        longitude: "longitude",
        # New uplink columns
        uplink_id: "uplink_id",
        uplink_type: "uplink_type"
      }
    end
  end
end
