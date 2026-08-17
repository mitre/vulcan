# frozen_string_literal: true

# Every authored-requirement COPY — Rule's amoeba clone, component
# duplication, release copy, and relocation move — must reset to fresh
# authoring state. All four delegate to BaseRule#reset_authored_copy_state,
# so this is the single assertion of the invariant: include it with a
# `copied_row` describing the produced copy to hold any path to it.
RSpec.shared_examples 'a reset authored copy' do
  it 'is unlocked' do
    expect(copied_row.locked).to be(false)
  end

  it 'is unclaimed (no review requestor)' do
    expect(copied_row.review_requestor_id).to be_nil
  end

  it 'has no field-level locks' do
    expect(copied_row.locked_fields).to eq({})
  end
end
