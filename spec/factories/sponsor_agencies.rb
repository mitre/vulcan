FactoryBot.define do
  factory :sponsor_agency_1, class: SponsorAgency do
    sponsor_name 'some sponsor'
    phone_number '7777777777'
    email 'sponsor@sponsor.com'
    organization 'DoD'
  end

  factory :sponsor_agency_2, class: SponsorAgency do
    sponsor_name 'some other sponsor'
    phone_number '7777777777'
    email 'othersponsor@othersponsor.com'
    organization 'DoD'
  end

  factory :invalid_sponsor_agency, class: SponsorAgency do
    sponsor_name nil
    phone_number '7777777777'
    email 'othersponsor@othersponsor.com'
    organization nil
  end
end
