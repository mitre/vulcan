# frozen_string_literal: true

require 'rails_helper'

# Mirrors rule_mergeable_fields_spec.rb. The merge engine
# (Applier#apply_review_field_updates) reads this constant; BackupSerializer
# review-projection and ReviewBuilder allowlist should also align.
RSpec.describe Review do
  describe '::MERGEABLE_FIELDS' do
    it 'is frozen so callers cannot mutate it' do
      expect(described_class::MERGEABLE_FIELDS).to be_frozen
    end

    it 'is a non-empty Array<String>' do
      expect(described_class::MERGEABLE_FIELDS).to be_an(Array)
      expect(described_class::MERGEABLE_FIELDS).not_to be_empty
      expect(described_class::MERGEABLE_FIELDS).to all(be_a(String))
    end

    it 'every entry exists as a real column on reviews' do
      missing = described_class::MERGEABLE_FIELDS - described_class.column_names
      expect(missing).to be_empty, "MERGEABLE_FIELDS lists non-existent columns: #{missing.inspect}"
    end

    it 'excludes identity / lifecycle / immutable columns' do
      identity_lifecycle = %w[
        id rule_id user_id action comment commentable_type commentable_id
        section created_at updated_at responding_to_review_id duplicate_of_review_id
        request_uuid commenter_imported_email commenter_imported_name
        original_commentable_id
      ]
      overlap = described_class::MERGEABLE_FIELDS & identity_lifecycle
      expect(overlap).to be_empty,
                         "MERGEABLE_FIELDS leaks identity/lifecycle columns: #{overlap.inspect}"
    end
  end
end
