FactoryBot.define do
  factory :cci, class: Cci do
    cci 'cci_number'
  end

  factory :cci2, class: Cci do
    cci 'cci_number'
  end

  factory :invalid_cci, class: Cci do
    cci nil
  end
end
