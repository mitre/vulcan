# frozen_string_literal: true

##
# XccdfParseable - Shared concern for models with XCCDF XML parsing
#
# Provides memoized XCCDF benchmark parsing for Component, STIG, and SRG models.
# Reduces duplication and ensures consistent parsing behavior across models.
#
# Usage:
#   class Component < ApplicationRecord
#     include XccdfParseable
#   end
#
#   component.parsed_benchmark  # Returns Xccdf::Benchmark, memoized
#   component.parsed_benchmark = benchmark  # Allows injection for testing
#
module XccdfParseable
  extend ActiveSupport::Concern

  ##
  # Parse the xml attribute into an Xccdf::Benchmark object
  # Results are memoized to avoid re-parsing on subsequent calls
  #
  # @return [Xccdf::Benchmark] Parsed benchmark object
  def parsed_benchmark
    @parsed_benchmark ||= Xccdf::Benchmark.parse(xml)
  end

  ##
  # Allow setting the parsed_benchmark directly
  # Useful for testing and pre-populating the cache
  #
  # @param benchmark [Xccdf::Benchmark] The benchmark object to set
  attr_writer :parsed_benchmark
end
