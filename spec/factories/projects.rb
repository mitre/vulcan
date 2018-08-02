FactoryBot.define do
  factory :project, class: Project do
    name 'Project Name'
    title 'Project Title'
    maintainer 'SOME MAINTAINER'
    copyright 'MyString'
    copyright_email 'MyString'
    license 'MyString'
    summary 'MyString'
    version 'MyString'
    status 'MyString'
    sponsor_agency_id { FactoryBot.create(:sponsor_agency_1).id }
    vendor_id { FactoryBot.create(:vendor_1).id }
  end

  factory :project2, class: Project do
    name 'MyString2'
    title 'MyString2'
    maintainer 'MyString2'
    copyright 'MyString2'
    copyright_email 'MyString2'
    license 'MyString2'
    summary 'MyString2'
    version 'MyString2'
    status 'MyString2'
    sponsor_agency_id { FactoryBot.create(:sponsor_agency_2).id }
    vendor_id { FactoryBot.create(:vendor_2).id }
  end
  
  factory :project_srg, class: Project do
    name 'Project Name'
    title 'Project Title'
    maintainer 'SOME MAINTAINER'
    copyright 'MyString'
    copyright_email 'MyString'
    license 'MyString'
    summary 'MyString'
    version 'MyString'
    status 'MyString'
    sponsor_agency_id { FactoryBot.create(:sponsor_agency_1).id }
    vendor_id { FactoryBot.create(:vendor_1).id }
    srg_ids { [FactoryBot.create(:srg).id, FactoryBot.create(:srg2).id] }
  end

  factory :invalid_project, class: Project do
    name nil
    title nil
    maintainer 'MyString'
    copyright 'MyString'
    copyright_email 'MyString'
    license 'MyString'
    summary 'MyString'
    version 'MyString'
    status nil
    sponsor_agency_id { FactoryBot.create(:invalid_sponsor_agency).id }
    vendor_id { FactoryBot.create(:vendor_1).id }
  end
end
# 
# FactoryBot.define do
#   factory :profile, class: Profile do
#     name 'MyString'
#     title 'MyString'
#     maintainer 'MyString'
#     copyright 'MyString'
#     copyright_email 'MyString'
#     license 'MyString'
#     summary 'MyString'
#     version 'MyString'
#     sha256 'MyString'
#   end
# 
#   factory :profile2, class: Profile do
#     name 'MyString2'
#     title 'MyString2'
#     maintainer 'MyString2'
#     copyright 'MyString2'
#     copyright_email 'MyString2'
#     license 'MyString2'
#     summary 'MyString2'
#     version 'MyString2'
#     sha256 'MyString2'
#   end
# 
#   factory :invalid_profile, class: Profile do
#     name nil
#     title nil
#     maintainer 'MyString'
#     copyright 'MyString'
#     copyright_email 'MyString'
#     license 'MyString'
#     summary 'MyString'
#     version 'MyString'
#     sha256 nil
#   end
# 
# end
