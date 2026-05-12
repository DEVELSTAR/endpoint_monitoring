FactoryBot.define do
  factory :endpoint_monitoring_group do
    name { Faker::Company.name }
    group_type { "network" }
    association :user

    transient do
      router_inventory { create(:router_inventory) }
    end
    associated_resources { [ "AP:#{router_inventory.id}" ] }

    trait :with_endpoints do
      transient do
        endpoints_count { 2 }
      end

      after(:create) do |group, evaluator|
        create_list(:endpoint_monitoring_endpoint, evaluator.endpoints_count, endpoint_monitoring_group: group)
      end
    end
  end
end
