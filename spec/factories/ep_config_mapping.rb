FactoryBot.define do
  factory :ep_config_mapping do
    resourceable_type { "RouterInventory" }
    resourceable_id   { 1 }
    association :endpoint_monitoring_group
  end
end
