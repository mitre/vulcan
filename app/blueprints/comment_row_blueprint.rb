# frozen_string_literal: true

# Unified serializer for comment listing rows, replacing three hand-built
# hashes in CommentQueryService, UsersController, and Project.
#
# Views:
#   default    — shared base fields for all consumers
#   :component — full triage view with attribution + rule status
#   :project   — cross-component view with component identifiers
#   :user      — my-comments view with project/component context
#
# Computed data (responses_count, reactions, rule_displayed_name) is passed
# via Blueprinter options hash since it's pre-aggregated in batch queries.
class CommentRowBlueprint < Blueprinter::Base
  identifier :id

  fields :comment, :created_at, :triage_status, :triage_set_at,
         :adjudicated_at, :duplicate_of_review_id, :section,
         :commentable_type, :rule_id, :addressed_by_rule_id

  field :author_name do |review, _options|
    review.commenter_display_name
  end

  field :rule_displayed_name do |review, options|
    if review.commentable_type == 'Component'
      '(component)'
    else
      options[:rule_display_map]&.dig(review.rule_id)
    end
  end

  field :addressed_by_rule_name do |review, options|
    review.addressed_by_rule_id ? options[:rule_display_map]&.dig(review.addressed_by_rule_id) : nil
  end

  field :responses_count do |review, options|
    options[:responses_counts]&.dig(review.id) || 0
  end

  field :reactions do |review, options|
    counts = options[:reaction_counts] || {}
    { up: counts[[review.id, 'up']] || 0, down: counts[[review.id, 'down']] || 0 }
  end

  # :component — full triage page with attribution, rule status, grouping
  view :component do
    extend ImportedAttributionFields

    attribution_fields :triager
    attribution_fields :adjudicator
    attribution_fields :commenter

    field :author_email do |review, _options|
      review.user&.email || review.commenter_imported_email
    end

    field :updated_at do |review, _options|
      review.updated_at
    end

    field :rule_status do |review, _options|
      review.commentable_type == 'Component' ? nil : review.commentable&.status
    end

    field :parent_rule_displayed_name do |review, options|
      if review.commentable_type == 'Component'
        nil
      else
        options[:parent_rule_map]&.dig(review.rule_id)
      end
    end

    field :group_rule_displayed_name do |review, options|
      if review.commentable_type == 'Component'
        nil
      else
        parent = options[:parent_rule_map]&.dig(review.rule_id)
        parent || options[:rule_display_map]&.dig(review.rule_id)
      end
    end
  end

  # :project — cross-component listing with component identifiers
  view :project do
    extend ImportedAttributionFields

    attribution_fields :triager
    attribution_fields :adjudicator

    field :component_id do |review, options|
      if review.commentable_type == 'Component'
        review.commentable_id
      else
        options[:rule_component_map]&.dig(review.rule_id)
      end
    end

    field :component_name do |review, options|
      cid = if review.commentable_type == 'Component'
              review.commentable_id
            else
              options[:rule_component_map]&.dig(review.rule_id)
            end
      options[:component_name_map]&.dig(cid)
    end
  end

  # :user — my-comments view with project + component context
  view :user do
    field :project_id do |review, _options|
      resolve_project(review)&.id
    end

    field :project_name do |review, _options|
      resolve_project(review)&.name
    end

    field :component_id do |review, _options|
      resolve_component(review)&.id
    end

    field :component_name do |review, _options|
      resolve_component(review)&.name
    end

    field :latest_activity_at do |review, options|
      latest_response = options[:latest_response_at]&.dig(review.id)
      [review.triage_set_at, review.adjudicated_at, latest_response].compact.max
    end
  end

  def self.resolve_component(review)
    if review.commentable_type == 'Component'
      review.commentable
    else
      (review.rule || review.commentable)&.component
    end
  end
  private_class_method :resolve_component

  def self.resolve_project(review)
    resolve_component(review)&.project
  end
  private_class_method :resolve_project
end
