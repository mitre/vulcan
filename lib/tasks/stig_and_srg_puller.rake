# frozen_string_literal: true

namespace :stig_and_srg_puller do
  desc 'Pull STIGs and SRGs from cyber.mil'
  task pull: :environment do
    puts 'This task will pull published STIGs and SRGs from cyber.mil and save them in Vulcan'
    data_url = 'https://raw.githubusercontent.com/mitre/inspec-profile-update-action/main/stigs.json'
    count = 0
    failed = 0
    begin
      response = RestClient.get(data_url)
      data = JSON.parse(response)
      data.each do |item|
        type = item['id'].split('_').last
        model = if type == 'STIG'
                  Stig
                else
                  type == 'SRG' ? SecurityRequirementsGuide : ''
                end
        if model.present? && item['file'].present?
          lookup = { model == Stig ? :stig_id : :srg_id => item['id'], version: item['version'] }
          existing_object = model.find_by(lookup)
          if existing_object.nil?
            xml = Nokogiri::XML(RestClient.get(item['file']))
            parsed_benchmark = Xccdf::Benchmark.parse(xml)
            new_object = model.from_mapping(parsed_benchmark)
            new_object.xml = xml
            if new_object.save
              count += 1
              Rails.logger.info "Successfully pulled and saved #{item['name']}"
            else
              msg = "STIG And SRG Puller Worker Error: Unable to save (#{item['name']}): ."
              Rails.logger.error msg + new_object.errors.full_messages.split(', ')
            end
          end

        end
      rescue StandardError => e
        puts e.message
        failed += 1
        next
      end
      puts "Loaded #{count} items."
      puts "Failed to load #{failed} items."
    rescue StandardError => e
      puts "STIG And SRG Puller Worker Error: Unable to fetch data from external source. #{e.message}"
      Rails.logger.error "STIG And SRG Puller Worker Error: Unable to fetch data from external source. #{e.message}"
    end
  end
end
