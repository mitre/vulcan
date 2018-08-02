FactoryBot.define do
  factory :admin_role, class: Role do
    name 'admin'
    resource_type 'something'
    created_at { Faker::Date.between(2.days.ago, Date.today) }
    updated_at { Faker::Date.between(2.days.ago, Date.today) }
  end

  factory :vendor_role, class: Role do
    name 'vendor'
    resource_type 'something'
    created_at { Faker::Date.between(2.days.ago, Date.today) }
    updated_at { Faker::Date.between(2.days.ago, Date.today) }
  end
  
  factory :sponsor_role, class: Role do
    name 'sponsor'
    resource_type 'something'
    created_at { Faker::Date.between(2.days.ago, Date.today) }
    updated_at { Faker::Date.between(2.days.ago, Date.today) }
  end

  factory :invalid_role, class: Role do
    status nil
    created_at { Faker::Date.between(2.days.ago, Date.today) }
    updated_at { Faker::Date.between(2.days.ago, Date.today) }
  end
end
