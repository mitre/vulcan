# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

require 'csv'
require 'services/CCIAttributes'

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