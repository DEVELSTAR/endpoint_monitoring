#!/usr/bin/env ruby
# Script to generate bulk ClickHouse test data for endpoint monitoring
# Generates 1 data point per minute for the last 24 hours
# org_id: 3, endpoint_id: 1


# Run: bundle exec rails runner db/seeds/clickhouse_test_data.rb

require 'time'

puts "Generating ClickHouse test data..."
puts "Configuration:"
puts "  - org_id: 3"
puts "  - endpoint_id: 1"
puts "  - Time range: Last 24 hours"
puts "  - Frequency: 1 point per minute"
puts "  - Total records: 1440"
puts "  - Associated resources: AP:1, network:541"
puts ""

# Configuration
# These values match the associated resources in the group:
# - AP:1 -> device_id (router MAC address)
# - network:541 -> router_inventory_id (network location)
ORG_ID = "3"
ENDPOINT_ID = "1"
HOST = "8.8.8.8"
DEVICE_ID = "00:25:22:2E:D2:41"  # AP:1 (Router MAC address)
ISP = "Test ISP"
REGION = "Test Region"
LOCATION_NETWORK_ID = "1"
ROUTER_INVENTORY_ID = "541"  # network:541 (matches associated resource)
LATITUDE = "28.6139"
LONGITUDE = "77.2090"
UPLINK_ID = "1"
UPLINK_TYPE = "primary"

# Time configuration
end_time = Time.now.utc
start_time = end_time - (24 * 60 * 60) # 24 hours ago
total_minutes = 24 * 60 # 1440 minutes

puts "Time range:"
puts "  - Start: #{start_time.strftime('%Y-%m-%d %H:%M:%S UTC')}"
puts "  - End: #{end_time.strftime('%Y-%m-%d %H:%M:%S UTC')}"
puts ""

# Generate data points
records = []
current_time = start_time

total_minutes.times do |i|
  # Generate realistic metrics with some variation
  latency_base = 20 + rand(30) # 20-50ms base latency
  latency_spike = (rand < 0.1) ? rand(50) : 0 # 10% chance of spike
  latency_ms = latency_base + latency_spike
  
  http_status = (rand < 0.95) ? 200 : [500, 502, 503].sample # 95% success rate
  tcp_status = (rand < 0.98) ? "success" : "failure" # 98% success rate
  
  record = {
    ts: current_time.strftime('%Y-%m-%d %H:%M:%S'),
    org_id: ORG_ID,
    endpoint_id: ENDPOINT_ID,
    host: HOST,
    device_id: DEVICE_ID,
    isp: ISP,
    region: REGION,
    location_network_id: LOCATION_NETWORK_ID,
    router_inventory_id: ROUTER_INVENTORY_ID,
    latitude: LATITUDE,
    longitude: LONGITUDE,
    uplink_id: UPLINK_ID,
    uplink_type: UPLINK_TYPE,
    latency_ms: latency_ms,
    http_status: http_status,
    tcp_status: tcp_status
  }
  
  records << record
  current_time += 60 # Add 1 minute
  
  # Progress indicator
  if (i + 1) % 100 == 0
    print "\rGenerating records... #{i + 1}/#{total_minutes}"
  end
end

puts "\r✓ Generated #{records.length} records"
puts ""

# Insert into ClickHouse
puts "Inserting data into ClickHouse..."

begin
  # Use ClickHouse model for inserts
  records.each_with_index do |record, index|
    Clickhouse::RouterMetricsRaw.create!(
      ts: record[:ts],
      org_id: record[:org_id],
      endpoint_id: record[:endpoint_id],
      host: record[:host],
      device_id: record[:device_id],
      isp: record[:isp],
      region: record[:region],
      location_network_id: record[:location_network_id],
      router_inventory_id: record[:router_inventory_id],
      latitude: record[:latitude],
      longitude: record[:longitude],
      uplink_id: record[:uplink_id],
      uplink_type: record[:uplink_type],
      latency_ms: record[:latency_ms],
      http_status: record[:http_status],
      tcp_status: record[:tcp_status]
    )
    
    # Progress indicator
    if (index + 1) % 100 == 0
      print "\rInserting records... #{index + 1}/#{records.length}"
    end
  end
  
  puts "\r✓ Inserted #{records.length} records into ClickHouse"
  
  # Verify insertion
  count = Clickhouse::RouterMetricsRaw.where(org_id: ORG_ID, endpoint_id: ENDPOINT_ID).count
  
  puts ""
  puts "Verification:"
  puts "  - Total records in ClickHouse: #{count}"
  puts "  - Expected records: #{records.length}"
  
  if count >= records.length
    puts "  - Status: ✓ Success"
  else
    puts "  - Status: ⚠ Warning - Record count mismatch"
  end
  
  # Show sample data
  puts ""
  puts "Sample data (first 3 records):"
  samples = Clickhouse::RouterMetricsRaw
    .where(org_id: ORG_ID, endpoint_id: ENDPOINT_ID)
    .order(:ts)
    .limit(3)
  
  samples.each_with_index do |row, i|
    puts "  #{i + 1}. #{row.ts} | Latency: #{row.latency_ms}ms | HTTP: #{row.http_status} | TCP: #{row.tcp_status}"
  end
  
  puts ""
  puts "✓ ClickHouse test data generation complete!"
  
rescue => e
  puts ""
  puts "✗ Error inserting data into ClickHouse:"
  puts "  #{e.class}: #{e.message}"
  puts ""
  puts "Stack trace:"
  puts e.backtrace.first(5).map { |line| "  #{line}" }.join("\n")
  exit 1
end
