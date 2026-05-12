# spec/factories/roles.rb
FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "role_#{n}" }

    trait :admin do
      name { "admin" }
    end
  end
end
