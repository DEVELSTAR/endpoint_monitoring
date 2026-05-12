# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    encrypted_password { 'password123' }
    full_name { Faker::Name.name }
    organisation_id { Faker::Number.number(digits: 5) }
    access_token { Faker::Alphanumeric.alphanumeric(number: 32) }
    association :role
  end

  factory :admin_user, parent: :user do
    association :role, factory: [ :role, :admin ]
  end
end
