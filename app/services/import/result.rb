# frozen_string_literal: true

module Import
  # Value object for import operation results.
  # Carries success state, errors, warnings, and a summary of what was created.
  class Result
    attr_reader :errors, :warnings, :summary

    def initialize
      @errors = []
      @warnings = []
      @summary = {}
    end

    def success?
      @errors.empty?
    end

    def add_error(message)
      @errors << message
    end

    def add_warning(message)
      @warnings << message
    end

    def merge_summary(hash)
      @summary.merge!(hash)
    end
  end
end
