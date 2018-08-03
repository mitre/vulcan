FactoryBot.define do
  factory :vendor_1, class: Vendor do
    vendor_name 'MyVendor'
    point_of_contact 'John Doe'
    poc_email 'john@vendor.com'
    poc_phone_number '7777777777'
  end

  factory :vendor_2, class: Vendor do
    vendor_name 'MyVendor2'
    point_of_contact 'Jane Doe'
    poc_email 'jane@vendor.com'
    poc_phone_number '7777777777'
  end

  factory :invalid_vendor, class: Vendor do
    vendor_name nil
    point_of_contact nil
    poc_email 'doe@vendor.com'
    poc_phone_number '7777777777'
  end
end
