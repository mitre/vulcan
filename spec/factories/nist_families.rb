FactoryBot.define do
  factory :nist_family1, class: NistFamily do
    family 'AC'
    version 'Rev. 4'
    short_title 'AC'
    long_title 'Access Control'
  end

  factory :invalid_nist_family, class: NistFamily do
    family nil
    version nil
    short_title nil
    long_title nil
  end
end