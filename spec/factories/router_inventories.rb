FactoryBot.define do
  factory :router_inventory do
    mac_id { Faker::Internet.mac_address }
    location_network_id { Faker::Number.number(digits: 6) }
    # Add other required fields for RouterInventory model
  end
end
