FactoryBot.define do
  factory :nist_control1, class: NistControl do
    family 'AC'
    index '1'
    version 'Rev. 4'
  end
  
  factory :nist_control2, class: NistControl do
    family 'AC'
    index '2'
    version 'Rev. 4'
  end

  factory :invalid_nist_control, class: NistControl do
    family 'SC@!'
    index 'ab2'
    version '12w'
  end
end