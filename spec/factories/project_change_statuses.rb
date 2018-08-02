FactoryBot.define do
  factory :pch_open, class: ProjectChangeStatus do
    status 'open'
    created_at 'somedate'
    updated_at 'somedate'
  end

  factory :pch_closed, class: ProjectChangeStatus do
    status 'closed'
    created_at 'somedate'
    updated_at 'somedate'
  end

  factory :invalid_pch, class: ProjectChangeStatus do
    status nil
    created_at 'somedate'
    updated_at 'somedate'
  end
end
