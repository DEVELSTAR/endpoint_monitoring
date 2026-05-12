FactoryBot.define do
  factory :endpoint_monitoring_endpoint do
    name { Faker::Internet.domain_name }
    host { "google.in" }
    monitoring_mode { "icmp" }
    port { 80 }
    latency_critical { 200 }
    latency_warning { 100 }
    response_time { 50 }
    acceptable_response_codes { "200,201" }
    association :endpoint_monitoring_group

    # Trait for ICMP endpoints (can use IP addresses)
    trait :icmp do
      monitoring_mode { "icmp" }
      host { "google.in" }
    end

    # Trait for HTTP endpoints (must use HTTP/HTTPS URLs)
    trait :http do
      monitoring_mode { "http" }
      host { "https://stackoverflow.com" }
      response_time { 1000 }
      acceptable_response_codes { "200,201,202" }
    end

    # Trait for TCP endpoints (can use IP addresses or domains)
    trait :tcp do
      monitoring_mode { "tcp" }
      host { "redis.example.net" }
      port { 443 }
    end
  end
end
