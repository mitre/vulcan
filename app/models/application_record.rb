# frozen_string_literal: true

# This is the base model for the application. Things should only be
# placed here if they are shared between multiple models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Deterministic in-memory ordering for an ALREADY-LOADED association, so a
  # serialized collection is stable across identical reads without re-querying
  # (calling .order on a loaded association re-queries → an N+1). Rule
  # collections use the version-based BaseRule.canonical_sort; these are the
  # generic fallbacks. `id` is always the final (unique) key → a total order.
  def self.sorted_by_id(collection)
    collection.sort_by(&:id)
  end

  # created_at first, then id to break same-timestamp ties (records saved in
  # one request can share a created_at). Used for reviews and other
  # chronological collections.
  def self.chronological(collection)
    collection.sort_by { |record| [record.created_at, record.id] }
  end

  ##
  # Build a structure that minimally describes the editing history of a model
  # and describes what can be reverted for that model.
  #
  # If `limit` is `nil`, then no limit will be applied on the number of histories returned
  #
  def histories(limit = 20)
    return unless defined?(own_and_associated_audits)

    # :id breaks created_at ties so histories are a deterministic total order.
    own_and_associated_audits.order(:created_at, :id).limit(limit).map(&:format)
  end
end
