FactoryBot.define do
  factory :location_network do
    network_name { Faker::Company.name + " Network" }
    # Add other required fields for LocationNetwork model
  end
end
