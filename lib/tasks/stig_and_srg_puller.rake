# frozen_string_literal: true

# rubocop:disable Metrics/BlockNesting

namespace :stig_and_srg_puller do
  desc "Pull STIGs and SRGs from cyber.mil"

  task load_data: :environment do
    puts "Loading data from cyber.mil ..."
    data_url = "https://raw.githubusercontent.com/mitre/inspec-profile-update-action/main/stigs.json"
    begin
      response = RestClient.get(data_url)
      @data = JSON.parse(response).uniq
    rescue StandardError => e
      puts "Error: Unable to load data: #{e.message}"
      @data = []
    end
  end

  task process_data: :load_data do
    puts "Processing data ..."
    @total = 0
    @new_items = 0
    @updated_items = 0
    @failed = 0
    @process_data = []

    @data.each do |item|
      new_item = { name: item["name"], file_present: item["file"].present?, xmls: [] }
      begin
        if new_item[:file_present]
          new_item[:xmls] << RestClient.get(item["file"])
          @total += 1
        else
          zip_response = RestClient.get(item["url"])
          # create a temp dir to extract zip contents
          temp_dir = Rails.root.join("tmp", "zip_extraction")
          FileUtils.mkdir_p(temp_dir)
          zip_file_path = File.join(temp_dir, "download_zip")
          File.binwrite(zip_file_path, zip_response.body)

          Zip::File.open(zip_file_path) do |zip_contents|
            entries = {}
            zip_contents.each do |entry|
              if (existing_entry = entries[entry.name])
                entries[entry.name] = entry if entry.time > existing_entry.time
              else
                entries[entry.name] = entry
              end
            end
            entries.each do |name, entry|
              next unless name.include?("xml")

              new_item[:xmls] << entry.get_input_stream.read
              @total += 1
            end
          end

          # Clean up temporary files
          FileUtils.rm_rf(temp_dir)
        end
      rescue StandardError => e
        puts "Error: Unable to read #{item["name"]} xml. #{e.message}"
        @total += 1
        @failed += 1
        next
      end
      @process_data << new_item
    end
  end

  task save_data: :process_data do
    puts "Saving STIG / SRG data in Vulcan..."
    @process_data.each do |item|
      item[:xmls].each do |xml|
        parsed_benchmark = Xccdf::Benchmark.parse(xml)
        title = parsed_benchmark.try(:title).try(:first).try(:downcase)
        model = if title&.include?("implementation guide") || title&.include?("stig")
            Stig
          else
            title&.include?("requirements guide") ? SecurityRequirementsGuide : ""
          end
        if model.present?
          new_object = model.from_mapping(parsed_benchmark)
          new_object.xml = Nokogiri::XML(xml)
          id = model == Stig ? new_object.stig_id : new_object.srg_id
          name = id.tr("_", " ").gsub(/(?<=\d)-/, ".")
          name = "#{name} - Ver #{new_object.version[1]}, Rel #{new_object.version.last}"
          new_object.name = item[:file_present] ? item[:name] : name
          if new_object.save
            @new_items += 1
            puts "Successfully pulled and saved #{new_object.name}"
          else
            lookup = { model == Stig ? :stig_id : :srg_id => id, version: new_object.version }
            existing_object = model.find_by(lookup)
            existing_object_date = model == Stig ? existing_object&.benchmark_date : existing_object&.release_date
            new_object_date = model == Stig ? new_object.benchmark_date : new_object.release_date
            next unless new_object_date > existing_object_date

            update_attributes = new_object.as_json.compact
            new_rules = if model == Stig
                parsed_benchmark.group.map do |grp|
                  StigRule.from_mapping(grp, existing_object&.id)
                end.index_by(&:version)
              else
                parsed_benchmark.rule.map do |rule|
                  SrgRule.from_mapping(rule,
                                       existing_object&.id)
                end.index_by(&:version)
              end
            existing_rules = model == Stig ? existing_object&.stig_rules : existing_object.srg_rules
            if existing_object&.update(update_attributes)
              existing_rules&.each do |existing_rule|
                new_rule = new_rules[existing_rule.version]
                next if new_rule.blank?

                rule_attributes = new_rule.as_json.compact
                rule_attributes.delete(:nist_control_family) # This is not a rule attribute, but a method
                existing_rule.update(rule_attributes)
              end
              if existing_object.save
                @updated_items += 1
                puts "Successfully updated #{item["name"]}"
              end
            else
              msg = "STIG And SRG Puller Worker Error: Unable to save/update (#{item["name"]}): ."
              puts msg + existing_object&.errors&.full_messages&.split(", ")
              @failed += 1
            end
          end
        end
      rescue StandardError => e
        puts "Error: Unable to save data: #{e.message}"
        @failed += 1
        next
      end
    end
  end

  task pull: :save_data do
    puts "Pull SRGs and STIGs data completed."
    puts "Total item count: #{@total}"
    puts "Loaded #{@new_items} items."
    puts "Updated #{@updated_items} items."
    puts "Failed to load #{@failed} items."
  end
end
# rubocop:enable Metrics/BlockNesting
