FactoryBot.define do
  factory :message do
    body { "test" }
    user
  end
end
