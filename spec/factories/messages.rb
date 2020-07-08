FactoryBot.define do
  factory :message do
    body { "test" }
    user_id { 1 }
    created_at { Time.zone.now }
  end
end
