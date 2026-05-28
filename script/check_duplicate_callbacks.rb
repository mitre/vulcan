#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to detect duplicate callback declarations in Rails controllers/models
# Rails overwrites callbacks with the same method name - this finds potential bugs
#
# Usage: ruby script/check_duplicate_callbacks.rb

CALLBACKS = %w[
  before_action after_action around_action
  before_filter after_filter around_filter
  before_validation after_validation
  before_save after_save around_save
  before_create after_create around_create
  before_update after_update around_update
  before_destroy after_destroy around_destroy
  after_commit after_rollback
  before_initialize after_initialize
  after_find after_touch
].freeze

def check_file(file_path)
  content = File.read(file_path)
  issues = []

  CALLBACKS.each do |callback_type|
    # Find all callback declarations: before_action :method_name
    matches = content.scan(/#{callback_type}\s+:(\w+)/).flatten

    # Group by method name and find duplicates
    duplicates = matches.group_by(&:itself).select { |_, v| v.size > 1 }

    duplicates.each do |method_name, occurrences|
      # Get line numbers for context
      lines = []
      content.each_line.with_index(1) do |line, num|
        lines << num if line.include?("#{callback_type} :#{method_name}")
      end

      issues << {
        callback: callback_type,
        method: method_name,
        count: occurrences.size,
        lines: lines
      }
    end
  end

  issues
end

def main
  puts "Checking for duplicate callback declarations...\n\n"

  dirs = %w[
    app/controllers
    app/models
    app/controllers/api
  ]

  total_issues = 0

  dirs.each do |dir|
    full_path = File.join(Dir.pwd, dir)
    next unless Dir.exist?(full_path)

    Dir.glob("#{full_path}/**/*.rb").sort.each do |file|
      issues = check_file(file)
      next if issues.empty?

      total_issues += issues.size
      relative_path = file.sub("#{Dir.pwd}/", '')
      puts "=== #{relative_path} ==="

      issues.each do |issue|
        puts "  DUPLICATE: #{issue[:callback]} :#{issue[:method]}"
        puts "    Appears #{issue[:count]} times on lines: #{issue[:lines].join(', ')}"
        puts "    WARNING: Later declaration overwrites earlier ones!"
      end
      puts
    end
  end

  if total_issues.zero?
    puts "No duplicate callbacks found."
  else
    puts "Found #{total_issues} potential issue(s)."
    puts "\nNote: Duplicate callbacks with the same method name will overwrite each other."
    puts "The LAST declaration wins, earlier ones are silently ignored."
    exit 1
  end
end

main if __FILE__ == $PROGRAM_NAME
