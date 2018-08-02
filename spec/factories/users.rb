FactoryBot.define do
  factory :user, class: User do
    # sequence(:id) {|n| "#{n}" }
    first_name { Faker::Name.name.split(' ')[0] }
    last_name { Faker::Name.name.split(' ')[1] }
    created_at { Faker::Date.between(2.days.ago, Date.today) }
    updated_at { Faker::Date.between(2.days.ago, Date.today) }
    sequence(:email) { |n| "user_#{n}@example.com" }
    password 'foobar'
    password_confirmation 'foobar'

    factory :vendor do
      first_name { Faker::Name.name.split(' ')[0] }
      last_name { Faker::Name.name.split(' ')[1] }
      created_at { Faker::Date.between(2.days.ago, Date.today) }
      updated_at { Faker::Date.between(2.days.ago, Date.today) }
      sequence(:email) { |n| "vendor_#{n}@example.com" }
      after(:create) { |user| user.add_role(:vendor) }
    end
    
    factory :sponsor do
      first_name { Faker::Name.name.split(' ')[0] }
      last_name { Faker::Name.name.split(' ')[1] }
      created_at { Faker::Date.between(2.days.ago, Date.today) }
      updated_at { Faker::Date.between(2.days.ago, Date.today) }
      sequence(:email) { |n| "sponsor_#{n}@example.com" }
      after(:create) { |user| user.add_role(:sponsor) }
    end

    factory :admin do
      first_name { Faker::Name.name.split(' ')[0] }
      last_name { Faker::Name.name.split(' ')[1] }
      created_at { Faker::Date.between(2.days.ago, Date.today) }
      updated_at { Faker::Date.between(2.days.ago, Date.today) }
      sequence(:email) { |n| "admin_#{n}@example.com" }
      after(:create) { |user| user.add_role(:admin) }
    end
  end
end

# FactoryBot.define do
#   factory :vendor, class: User do
#     id 1
#     password 'foobar'
#     password_confirmation 'foobar'
#     sequence(:email) { |n| "vendor@example.com" }
#     first_name { Faker::Name.name.split(' ')[0] }
#     last_name { Faker::Name.name.split(' ')[1] }
#     phone_number  { Faker::PhoneNumber.phone_number }
#     sign_in_count 0
#     after(:create) { |user| user.add_role(:vendor) }
#   end
# 
#   factory :sponsor, class: User do
#     id 2
#     password 'foobar'
#     password_confirmation 'foobar'
#     first_name { Faker::Name.name.split(' ')[0] }
#     last_name { Faker::Name.name.split(' ')[1] }
#     phone_number  { Faker::PhoneNumber.phone_number }
#     sign_in_count 0
#     sequence(:email) { |n| "sponsor@example.com" }
#     after(:create) { |user| user.add_role(:sponsor) }
#   end
# 
#   factory :admin, class: User do
#     id 3
#     password 'foobar'
#     password_confirmation 'foobar'
#     first_name { Faker::Name.name.split(' ')[0] }
#     last_name { Faker::Name.name.split(' ')[1] }
#     phone_number  { Faker::PhoneNumber.phone_number }
#     sign_in_count 0
#     sequence(:email) { |n| "admin@example.com" }
#     after(:create) { |user| user.add_role(:admin) }
#   end
# 
# 
#   factory :user do
#     id 4
#     password 'foobar'
#     password_confirmation 'foobar'
#     first_name { Faker::Name.name.split(' ')[0] }
#     last_name { Faker::Name.name.split(' ')[1] }
#     phone_number  { Faker::PhoneNumber.phone_number }
#     sign_in_count 0
#     sequence(:email) { |n| "user@example.com" }
#     after(:create) { |user| user.add_role(:admin) }
#   end
# end
