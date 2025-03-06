namespace :migration do
  desc "Find all templates using javascript_pack_tag"
  task find_pack_tags: :environment do
    require 'fileutils'

    # Directory to search in
    search_dir = Rails.root.join('app', 'views')
    output_file = Rails.root.join('MIGRATION_INVENTORY.md')
    
    # Patterns to search for
    patterns = [
      'javascript_pack_tag',
      'stylesheet_pack_tag',
      'image_pack_tag'
    ]
    
    # Results will be stored here
    results = {}
    patterns.each { |pattern| results[pattern] = [] }
    
    # Search for the patterns in all files
    puts "Searching for asset pack tags in #{search_dir}..."
    Dir.glob("#{search_dir}/**/*").each do |file|
      next if File.directory?(file)
      
      begin
        content = File.read(file)
        
        patterns.each do |pattern|
          if content.include?(pattern)
            relative_path = file.sub(Rails.root.to_s, '')
            line_numbers = []
            
            content.lines.each_with_index do |line, i|
              line_numbers << (i + 1) if line.include?(pattern)
            end
            
            entry_points = []
            content.scan(/#{pattern}\s+['"]([^'"]+)['"]/) do |match|
              entry_points << match[0]
            end
            
            results[pattern] << {
              file: relative_path,
              lines: line_numbers,
              entry_points: entry_points.uniq
            }
          end
        end
      rescue => e
        puts "Error reading file #{file}: #{e.message}"
      end
    end
    
    # Extract all unique entry points
    all_entry_points = []
    results.each do |_, result_list|
      result_list.each do |result|
        all_entry_points.concat(result[:entry_points])
      end
    end
    unique_entry_points = all_entry_points.uniq.sort
    
    # Write the results to a markdown file
    puts "Writing results to #{output_file}..."
    FileUtils.mkdir_p(File.dirname(output_file))
    
    File.open(output_file, 'w') do |f|
      f.puts "# Asset Pack Tags Migration Inventory"
      f.puts
      f.puts "This file lists all templates using asset pack tags that need to be migrated."
      f.puts
      
      patterns.each do |pattern|
        f.puts "## #{pattern}"
        f.puts
        
        if results[pattern].empty?
          f.puts "No occurrences found."
        else
          f.puts "| File | Line Numbers | Entry Points |"
          f.puts "|------|--------------|-------------|"
          
          results[pattern].each do |result|
            f.puts "| #{result[:file]} | #{result[:lines].join(', ')} | #{result[:entry_points].join(', ')} |"
          end
        end
        
        f.puts
      end
      
      # Write a migration plan
      f.puts "## Migration Plan"
      f.puts
      f.puts "### Entry Point Mapping"
      f.puts
      f.puts "| Webpacker Entry Point | Migrated Entry Point | Status |"
      f.puts "|----------------------|---------------------|--------|"
      
      unique_entry_points.each do |entry_point|
        migrated = ['application', 'login', 'navbar', 'toaster'].include?(entry_point) ? "✅" : "❌"
        f.puts "| #{entry_point} | app/javascript/#{entry_point}.js | #{migrated} |"
      end
    end
    
    puts "Done! Found #{results.values.flatten.size} uses of asset pack tags across #{unique_entry_points.size} unique entry points."
  end

  desc "Create error log for recent Rails errors"
  task log_errors: :environment do
    require 'fileutils'
    
    # Read the last 1000 lines from the Rails log
    log_file = Rails.root.join('log', 'development.log')
    error_log = Rails.root.join('ERROR_LOG.md')
    
    lines = `tail -n 1000 #{log_file}`
    
    # Extract error sections
    error_sections = []
    current_section = []
    in_error = false
    
    lines.each_line do |line|
      if line.include?('Error') || line.include?('Exception')
        in_error = true
        current_section = [line]
      elsif in_error
        if line.strip.empty? || line.include?('Started')
          in_error = false
          error_sections << current_section.join if current_section.any?
          current_section = []
        else
          current_section << line
        end
      end
    end
    
    # Add the last section if we're still in an error
    error_sections << current_section.join if in_error && current_section.any?
    
    # Write the errors to a markdown file
    FileUtils.mkdir_p(File.dirname(error_log))
    
    File.open(error_log, 'w') do |f|
      f.puts "# Recent Rails Errors"
      f.puts
      f.puts "This file contains recent errors from the Rails log."
      f.puts
      
      if error_sections.empty?
        f.puts "No errors found in the log."
      else
        error_sections.each_with_index do |section, i|
          f.puts "## Error #{i + 1}"
          f.puts
          f.puts "```"
          f.puts section
          f.puts "```"
          f.puts
        end
      end
    end
    
    puts "Error log created at #{error_log} with #{error_sections.size} error sections."
  end
end