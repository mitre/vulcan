# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
require 'csv'
require 'CCIAttributes'
require 'StigAttributes'
require 'pry'



def parse_xccdf(srg_file_name)
  controls = []
  srg_hash = {}
  xccdf_xml = File.read('./data/srgs/' + srg_file_name)
  cci_xml = File.read('data/U_CCI_List.xml')
  cci_items = Services::CCI_List.parse(cci_xml)
  xccdf = Services::Benchmark.parse(xccdf_xml)
  srg_hash[:title] = xccdf.title
  srg_hash[:description] = xccdf.description
  srg_hash[:publisher] = xccdf.reference.publisher
  srg_hash[:published] = xccdf.release_date.release_date

  xccdf.group.each do |group|
    control = {
      control_params: {},
      nist_params: {}
    }
    puts group.inspect
    control[:control_params][:control_id]    = group.id
    control[:control_params][:srg_title_id]  = group.title
    control[:control_params][:title]         = group.rule.title
    control[:control_params][:description]   = group.rule.description.gsub(/<\w?*>|<\/\w?*>/, '')
    control[:control_params][:severity]      = get_impact(group.rule.severity)
    control[:control_params][:checktext]     = group.rule.check.check_content
    control[:control_params][:fixtext]       = group.rule.fixtext
    control[:control_params][:fixid]         = group.rule.fix.id
    
    nist_family_from_cci = cci_items.fetch_nists(group.rule.idents)
    if nist_family_from_cci.length == 2
      nist_family = NistFamily.find_by(short_title: nist_family_from_cci[0].split('-')[0])
      index = nist_family_from_cci[0].split('-')[1].strip.sub(' ', '').sub(' ', '.') + '.'
      index = nist_family_from_cci[0].split('-')[1].strip.gsub(') (', ')(') if nist_family_from_cci[0].include?('(')
      index = nist_family_from_cci[0].split('-')[1].strip if nist_family_from_cci[0].split('-')[1].strip.match(/\A\d{1,2}\z/)
      control[:nist_params] = NistControl.find_by(index: index, nist_families_id: nist_family.id)
    end

    controls << control
  end
  [controls, srg_hash]
end

# @!method get_impact(severity)
#   Takes in the STIG severity tag and converts it to the InSpec #{impact}
#   control tag.
#   At the moment the mapping is static, so that:
#     high => 0.7
#     medium => 0.5
#     low => 0.3
# @param severity [String] the string value you want to map to an InSpec
# 'impact' level.
#
# @return impact [Float] the impact level level mapped to the XCCDF severity
# mapped to a float between 0.0 - 1.0.
#
# @todo Allow for the user to pass in a hash for the desired mapping of text
# values to numbers or to override our hard coded values.
#
def get_impact(severity)
  impact = case severity
           when 'low' then 0.3
           when 'medium' then 0.5
           else 0.7
           end
  impact
end

CSV.foreach('data/nist_families.txt', { :col_sep => "\t" }) do |row|
  short_title = row[0]
  long_title = row[1]
  NistFamily.create({short_title: short_title, long_title: long_title})
end

CSV.foreach('data/800-53-controls.txt', { :col_sep => "\t" }) do |row|
  family = row[1]
  index = family.split('-')
  nist_family = NistFamily.find_by short_title: index[0]
  NistControl.create({family: index[0], index: index[1], version: '4', nist_families_id: nist_family.id})
end

# Prepopulate all of the SRGs
Dir.entries('./data/srgs').each do |srg_file_name|
  next if srg_file_name == '.' || srg_file_name == '..'
  puts "here"
  # authorize! :create, Srg
  srg_controls, srg_hash = parse_xccdf(srg_file_name)
  
  @srg = Srg.create(srg_hash)
  srg_controls.each do |srg_control|
    @srg_control = @srg.srg_controls.create(srg_control[:control_params])
    @srg_control.nist_controls << srg_control[:nist_params] if srg_control[:nist_params] != {}
  end
end

cci_xml = File.read('data/U_CCI_List.xml')
cci_items = Services::CCI_List.parse(cci_xml).cci_items[0].cci_item
cci_items.each do |cci_item|
  cci = Cci.create({cci: cci_item.id})
  cci_item.references.references.each do |reference|
    if reference.version == '4'
      index = reference.index.split('-')[1].strip.sub(' ', '').sub(' ', '.') + '.'
      index = reference.index.split('-')[1].strip.gsub(') (', ')(') if reference.index.include?('(')
      index = reference.index.split('-')[1].strip if reference.index.split('-')[1].strip.match(/\A\d{1,2}\z/)
      nist_family = NistFamily.find_by(short_title: reference.index.split('-')[0])
      if !nist_family.nil?
        nist_control = NistControl.find_by(index: index, nist_families_id: nist_family.id)
        cci.nist_controls << nist_control
      end
    end  
  end
end

user = User.new
user.email = 'admin@admin.com'
user.password = 'admin1'
user.save
user.add_role "admin"

if true
  puts "DEVELOPMENT"
  vendor = Vendor.new
  vendor.vendor_name = 'vendor'
  vendor.save
  
  sponsor = SponsorAgency.new
  sponsor.sponsor_name = 'sponsor'
  sponsor.save
  
  user_vendor = User.new
  user_vendor.email = 'vendor@vendor.com'
  user_vendor.password = 'vvvvvv'
  user_vendor.vendors << vendor
  user_vendor.save
  user_vendor.add_role 'vendor'
  
  user_sponsor = User.new
  user_sponsor.email = 'sponsor@sponsor.com'
  user_sponsor.password = 'vvvvvv'
  user_sponsor.sponsor_agencies << sponsor
  user_sponsor.save
  user_sponsor.add_role 'sponsor'
end
