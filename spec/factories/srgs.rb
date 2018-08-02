FactoryBot.define do
  factory :srg, class: Srg do
    title 'MyString'
    description 'MyString'
    publisher 'MyString'
    published 'MyString'
  end

  factory :srg2, class: Srg do
    title 'MyString2'
    description 'MyString2'
    publisher 'MyString2'
    published 'MyString2'
  end

  factory :invalid_srg, class: Srg do
    title nil
    description nil
    publisher 'MyString'
    published 'MyString'
  end
end
