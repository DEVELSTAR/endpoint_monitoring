# Initial test data setup
# Creates 1 group with 1 endpoint for testing
# org_id: 3, user_id: 4, endpoint_id: 1

# Run: bundle exec rails runner db/seeds/group_test_data.rb

puts "Creating initial test data..."

# Create the group with associated resources
# Note: Skip validation for test data since AP:1 and network:541 may not exist in legacy DB
group = EndpointMonitoringGroup.new(
  id: 1,
  name: "Test Monitoring Group",
  group_type: "test",
  user_id: 4,
  organisation_id: 3,
  associated_resources_cache: ["AP:1", "network:541"]
)
group.save!(validate: false)

puts "✓ Created group: #{group.name} (ID: #{group.id})"
puts "  - Associated resources: #{group.associated_resources_cache.join(', ')}"

# Create the endpoint (ICMP mode for simplicity)
endpoint = EndpointMonitoringEndpoint.create!(
  id: 1,
  endpoint_monitoring_group_id: group.id,
  name: "Google DNS",
  host: "8.8.8.8",
  monitoring_mode: "icmp",
  latency_critical: 100,
  latency_warning: 50
)

puts "✓ Created endpoint: #{endpoint.name} (ID: #{endpoint.id})"
puts "  - Host: #{endpoint.host}"
puts "  - Mode: #{endpoint.monitoring_mode}"
puts "  - Latency thresholds: Warning=#{endpoint.latency_warning}ms, Critical=#{endpoint.latency_critical}ms"

puts "\n✓ Initial test data created successfully!"
puts "  - Group ID: #{group.id}"
puts "  - Endpoint ID: #{endpoint.id}"
puts "  - User ID: #{group.user_id}"
puts "  - Organisation ID: #{group.organisation_id}"
