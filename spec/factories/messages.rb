FactoryBot.define do
  factory :message do
    body { "test" }
    user { nil }
    user_id { nil }
    created_at { Time.zone.now }
  end
end
