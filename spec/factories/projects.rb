# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    name { generate(:name) }

    trait :with_admin do
      transient do
        admin_user { nil }
      end

      after(:create) do |project, evaluator|
        user = evaluator.admin_user || create(:user)
        create(:membership, :admin, user: user, membership: project)
      end
    end

    trait :with_members do
      transient do
        member_roles { %w[viewer author reviewer admin] }
      end

      after(:create) do |project, evaluator|
        evaluator.member_roles.each do |role|
          create(:membership, user: create(:user), membership: project, role: role)
        end
      end
    end
  end
end
