FactoryBot.define do
  factory :cch_open, class: ControlChangeStatus do
    status 'open'
    created_at 'somedate'
    updated_at 'somedate'
  end

  factory :cch_closed, class: ControlChangeStatus do
    status 'closed'
    created_at 'somedate'
    updated_at 'somedate'
  end

  factory :invalid_cch, class: ControlChangeStatus do
    status nil
    created_at 'somedate'
    updated_at 'somedate'
  end
end
