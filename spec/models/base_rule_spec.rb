# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseRule do
  # The one home for the copied-row invariant that Rule's amoeba block,
  # ComponentCopy, ReleaseCopyService, and RelocationExecutor all delegate
  # to — so a new reset added here covers every copy path at once.
  describe '#reset_authored_copy_state' do
    subject(:copied_row) do
      Rule.new(locked: true, review_requestor_id: 123, locked_fields: { 'title' => true })
          .reset_authored_copy_state
    end

    it_behaves_like 'a reset authored copy'

    it 'returns self so it can be chained onto dup_with_nested_records' do
      row = Rule.new(locked: true)
      expect(row.reset_authored_copy_state).to be(row)
    end
  end
end
