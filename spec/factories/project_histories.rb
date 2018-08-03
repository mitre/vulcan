FactoryBot.define do
  factory :project_history1, class: ProjectHistory do
    project_attr 'applicability'
    text 'comment'
    history_type 'comment'
    created_at { Faker::Date.between(2.days.ago, Date.today) }
    updated_at { Faker::Date.between(2.days.ago, Date.today) }
  end

  factory :project_history2, class: ProjectHistory do
    project_attr 'title'
    text 'reply'
    history_type 'reply'
    created_at { Faker::Date.between(2.days.ago, Date.today) }
    updated_at { Faker::Date.between(2.days.ago, Date.today) }
  end

  factory :invalid_project_history, class: ProjectHistory do
    project_attr nil
    text ''
    history_type nil
    created_at { Faker::Date.between(2.days.ago, Date.today) }
    updated_at { Faker::Date.between(2.days.ago, Date.today) }
  end
end
