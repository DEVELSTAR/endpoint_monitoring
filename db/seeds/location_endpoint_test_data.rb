# Test data for location_endpoints API
# Run with: rails db:seed:location_endpoint_test_data
# Or: rails runner db/seeds/location_endpoint_test_data.rb

puts "Creating test data for location_endpoints API..."

# Create admin user with org_id = 3
admin_role = Role.find_or_create_by!(name: 'admin') do |role|
  role.description = 'Administrator'
end

admin_user = User.find_or_initialize_by(email: 'admin@test.com')
admin_user.assign_attributes(
  firstname: 'Test',
  lastname: 'Admin',
  password: 'password123',
  password_confirmation: 'password123',
  role: admin_role,
  organisation_id: 3,
  access_token: SecureRandom.hex(10)
)
admin_user.save(validate: false)
puts "Created admin user: #{admin_user.email} (org_id: #{admin_user.organisation_id})"

# Create endpoint monitoring group for org_id = 3
group = EndpointMonitoringGroup.find_or_initialize_by(id: 1)
group.assign_attributes(
  name: 'Test Group',
  organisation_id: 3,
  user_id: admin_user.id
)
group.save(validate: false)
puts "Created endpoint monitoring group: #{group.name}"

# Reset auto-increment for endpoint_monitoring_endpoints to allow specific IDs
ActiveRecord::Base.connection.execute("ALTER TABLE endpoint_monitoring_endpoints AUTO_INCREMENT = 100")

# Create endpoints with specific IDs for testing
test_endpoints = [
  # Delhi endpoints - good
  { id: 1, name: 'Google', host: 'http://google.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  { id: 2, name: 'Cloudflare', host: 'http://cloudflare.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  
  # Mumbai endpoints - mixed
  { id: 3, name: 'AWS', host: 'http://aws.amazon.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  { id: 4, name: 'Azure', host: 'http://azure.microsoft.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  { id: 5, name: 'Bad Endpoint', host: 'http://bad-endpoint.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  
  # Delhi - critical (unstable)
  { id: 6, name: 'Unstable API', host: 'http://unstable-api.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  
  # Bangalore - critical (high latency)
  { id: 7, name: 'Slow Service', host: 'http://slow-service.io', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  { id: 8, name: 'Medium Latency', host: 'http://medium-latency.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  
  # Mumbai - down (failures)
  { id: 9, name: 'Broken API', host: 'http://broken-api.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
  
  # Delhi - down (TCP failures)
  { id: 10, name: 'TCP Failing', host: 'tcp-failing.net', monitoring_mode: 'tcp', 
    latency_warning: 100, latency_critical: 200, response_time: nil, acceptable_response_codes: nil, port: 443 },
  
  # Bangalore - down (extreme latency)
  { id: 11, name: 'Timeout Service', host: 'http://timeout-service.com', monitoring_mode: 'http', 
    latency_warning: 100, latency_critical: 200, response_time: 100, acceptable_response_codes: [200], port: nil },
]

test_endpoints.each do |ep_data|
  endpoint = EndpointMonitoringEndpoint.find_or_initialize_by(id: ep_data[:id])
  endpoint.assign_attributes(
    name: ep_data[:name],
    host: ep_data[:host],
    monitoring_mode: ep_data[:monitoring_mode],
    endpoint_monitoring_group_id: group.id,
    latency_warning: ep_data[:latency_warning],
    latency_critical: ep_data[:latency_critical],
    packet_loss_warning: 5,
    packet_loss_critical: 10,
    response_time: ep_data[:response_time],
    acceptable_response_codes: ep_data[:acceptable_response_codes],
    port: ep_data[:port]
  )
  endpoint.save(validate: false)
  puts "Created endpoint #{ep_data[:id]}: #{ep_data[:name]}"
end

puts "\nTest data created successfully!"
puts "Admin User Email: admin@test.com"
puts "Admin User Token: #{admin_user.access_token}"
puts "Organisation ID: 3"
puts "\nAPI Test Command:"
puts "curl -X GET 'http://localhost:3000/api/v1/dashboard/location_endpoints' \\"
puts "  -H 'X-AUTH-TOKEN: #{admin_user.access_token}'"
