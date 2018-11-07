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
require 'inspec_tools'

DATA_NOT_FOUND_MESSAGE = 'N/A'.freeze

def parse_nist_params(nist_family_from_cci)
  if nist_family_from_cci.length == 2
    nist_family = NistFamily.find_by(short_title: nist_family_from_cci[0].split('-')[0])
    index = nist_family_from_cci[0].split('-')[1].strip.sub(' ', '').sub(' ', '.') + '.'
    index = nist_family_from_cci[0].split('-')[1].strip.gsub(') (', ')(') if nist_family_from_cci[0].include?('(')
    index = nist_family_from_cci[0].split('-')[1].strip if nist_family_from_cci[0].split('-')[1].strip =~ /\A\d{1,2}\z/
    NistControl.find_by(index: index, nist_families_id: nist_family.id)
  else
    {}
  end
end

def parse_control(profile_control)
  control = {
    control_params: {},
    nist_params: {}
  }
  control[:control_params][:control_id]    = profile_control['id']             || DATA_NOT_FOUND_MESSAGE
  control[:control_params][:srg_title_id]  = profile_control['tags']['gtitle'] || DATA_NOT_FOUND_MESSAGE
  control[:control_params][:title]         = profile_control['title']          || DATA_NOT_FOUND_MESSAGE
  control[:control_params][:description]   = profile_control['desc']           || DATA_NOT_FOUND_MESSAGE
  control[:control_params][:severity]      = profile_control['impact']         || DATA_NOT_FOUND_MESSAGE
  control[:control_params][:checktext]     = profile_control['tags']['check']  || DATA_NOT_FOUND_MESSAGE
  control[:control_params][:fixtext]       = profile_control['tags']['fix']    || DATA_NOT_FOUND_MESSAGE
  control[:control_params][:fixid]         = profile_control['tags']['fix_id'] || DATA_NOT_FOUND_MESSAGE

  control[:nist_params] = parse_nist_params(profile_control['tags']['nist'])
  control
end

def parse_xccdf(srg_file_name)
  xccdf_xml = File.read("#{Rails.root}/data/srgs/" + srg_file_name)
  xccdf_tool = InspecTools::XCCDF.new(xccdf_xml)
  profile = xccdf_tool.to_inspec
  controls = profile['controls'].map { |profile_control| parse_control(profile_control) }
  srg_hash = {}
  srg_hash[:title] = profile['title']
  srg_hash[:description] = profile['summary']
  srg_hash[:publisher] = xccdf_tool.publisher
  srg_hash[:published] = xccdf_tool.published
  [controls, srg_hash]
end

CSV.foreach("#{Rails.root}/data/nist_families.txt", { col_sep: "\t" }) do |row|
  short_title = row[0]
  long_title = row[1]
  NistFamily.create({ short_title: short_title, long_title: long_title })
end

CSV.foreach("#{Rails.root}/data/800-53-controls.txt", { col_sep: "\t" }) do |row|
  family = row[1]
  index = family.split('-')
  nist_family = NistFamily.find_by short_title: index[0]
  NistControl.create({ family: index[0], index: index[1], version: '4', nist_families_id: nist_family.id })
end

# Prepopulate all of the SRGs
Dir.entries("#{Rails.root}/data/srgs").each do |srg_file_name|
  next if ['.', '..'].include?(srg_file_name)

  # authorize! :create, Srg
  srg_controls, srg_hash = parse_xccdf(srg_file_name)

  @srg = Srg.create(srg_hash)
  srg_controls.each do |srg_control|
    @srg_control = @srg.srg_controls.create(srg_control[:control_params])
    @srg_control.nist_controls << srg_control[:nist_params] if srg_control[:nist_params] != {}
  end
end

cci_xml = File.read("#{Rails.root}/data/U_CCI_List.xml")
cci_items = Services::CciList.parse(cci_xml).cci_items[0].cci_item
cci_items.each do |cci_item|
  cci = Cci.create({ cci: cci_item.id })
  cci_item.references.references.each do |reference|
    next unless reference.version == '4'

    index = reference.index.split('-')[1].strip.sub(' ', '').sub(' ', '.') + '.'
    index = reference.index.split('-')[1].strip.gsub(') (', ')(') if reference.index.include?('(')
    index = reference.index.split('-')[1].strip if reference.index.split('-')[1].strip =~ /\A\d{1,2}\z/
    nist_family = NistFamily.find_by(short_title: reference.index.split('-')[0])
    if !nist_family.nil?
      nist_control = NistControl.find_by(index: index, nist_families_id: nist_family.id)
      cci.nist_controls << nist_control
    end
  end
end

case Rails.env
when 'development'
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
  user_vendor.created_at = Date.new
  user_vendor.updated_at = Date.new
  user_vendor.save
  user_vendor.add_role 'vendor'

  user_sponsor = User.new
  user_sponsor.email = 'sponsor@sponsor.com'
  user_sponsor.password = 'vvvvvv'
  user_sponsor.created_at = Date.new
  user_sponsor.updated_at = Date.new
  user_sponsor.sponsor_agencies << sponsor
  user_sponsor.save
  user_sponsor.add_role 'sponsor'
end
