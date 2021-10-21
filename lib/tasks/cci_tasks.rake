# frozen_string_literal: true

require 'nokogiri'
require 'erb'

namespace :cci do
  desc 'Parse a version of CCI XML to NIST Mapping into Ruby Data Structure'
  task parse_cci_to_nist: :environment do
    raise 'Requires VULCAN_CCI_XML_PATH to be set' if ENV['VULCAN_CCI_XML_PATH'].nil?

    xml_path = Pathname.new(ENV['VULCAN_CCI_XML_PATH'])
    raise "No file exists at #{xml_path}" unless File.exist?(xml_path)

    template = ERB.new(File.read(Rails.root.join('lib', 'assets', 'cci_to_nist_constants.rb.erb')), trim_mode: '-')
    parsed_cci_xml = Nokogiri::XML(File.open(xml_path)).remove_namespaces!
    cci_xml_items = parsed_cci_xml.xpath('//cci_list/cci_items/cci_item')
    @cci_to_nist_mapping = {}
    cci_xml_items.each do |item|
      cci_number = item.attributes['id'].value
      # Get NIST 800-53 revision 4
      # rubocop:disable Layout/LineLength
      nist_control = item.xpath('./references/reference[not(@version <= preceding-sibling::reference/@version) and not(@version <=following-sibling::reference/@version)]/@index').text
      # rubocop:enable Layout/LineLength
      @cci_to_nist_mapping[cci_number.to_sym] = nist_control
    end
    @last = @cci_to_nist_mapping.keys.last
    File.write(Rails.root.join('app', 'lib', 'cci_map', 'constants.rb'), template.result)
    puts('Running `bundle exec rubocop -a app/lib/cci_map/constants.rb` to finish.')
    system('bundle exec rubocop -a app/lib/cci_map/constants.rb')
  end
end
