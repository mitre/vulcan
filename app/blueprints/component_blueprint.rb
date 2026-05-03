# frozen_string_literal: true

# Serializes Component records with context-specific views.
#
# Views:
#   :index  — listing page (minimal fields + severity_counts)
#   :show   — non-member read-only view (adds rules, reviews)
#   :editor — full editing page (adds histories, memberships, metadata, etc.)
#
# Replaces Component#as_json override and the to_json(methods: [...]) pattern.
# The `admins` method is intentionally excluded — Vue analysis confirmed no
# component page consumer reads component.admins (it's only used on project pages).
class ComponentBlueprint < Blueprinter::Base
  identifier :id

  # === Default: fields shared by ALL views ===
  fields :name, :prefix, :version, :release

  field :based_on_title do |component, _options|
    component.based_on&.title
  end

  field :based_on_version do |component, _options|
    component.based_on&.version
  end

  field :severity_counts do |component, _options|
    component.severity_counts_hash
  end

  # Pending top-level comment count for this component. Surfaces a
  # "N pending" badge on the component card so reviewers discover the
  # triage queue without drilling in. Pre-batched via
  # Component.pending_comment_counts and passed through render options.
  field :pending_comment_count do |component, options|
    counts = options[:pending_comment_counts] || {}
    counts[component.id] || 0
  end

  # === Index view: listing page ===
  # rules_count drives ComponentCard's controls badge; component_id
  # drives the (Overlaid) tag. Without these the card silently hides
  # the badges (the "Not Configured" bug Aaron flagged).
  view :index do
    fields :updated_at, :released, :rules_count, :component_id
  end

  # === Related view: related_rules parents (includes project for display name) ===
  view :related do
    fields :updated_at, :released

    field :project do |component, _options|
      ProjectBlueprint.render_as_hash(component.project)
    end
  end

  # === Show view: non-member read-only ===
  view :show do
    fields :title, :description, :admin_name, :admin_email, :released, :updated_at,
           :comment_phase, :closed_reason, :comment_period_starts_at, :comment_period_ends_at

    association :rules, blueprint: RuleBlueprint, view: :viewer do |component, _options|
      component.rules
    end

    # Uses Component#reviews method (not ReviewBlueprint) because it returns
    # pre-formatted hashes with `displayed_rule_name` that ReviewBlueprint lacks.
    field :reviews do |component, _options|
      component.reviews
    end
  end

  # === Editor view: full editing page ===
  view :editor do
    # All DB columns needed by Vue components
    fields :title, :description, :admin_name, :admin_email,
           :released, :advanced_fields, :project_id, :component_id,
           :security_requirements_guide_id, :memberships_count,
           :rules_count, :updated_at, :created_at,
           :comment_phase, :closed_reason, :comment_period_starts_at, :comment_period_ends_at

    field :releasable do |component, _options|
      component.releasable
    end

    field :status_counts do |component, _options|
      component.status_counts
    end

    field :additional_questions do |component, _options|
      component.additional_questions.as_json
    end

    # Rules via RuleBlueprint :editor view
    association :rules, blueprint: RuleBlueprint, view: :editor do |component, _options|
      component.rules
    end

    # Uses Component#reviews method (not ReviewBlueprint) because it returns
    # pre-formatted hashes with `displayed_rule_name` that ReviewBlueprint lacks.
    field :reviews do |component, _options|
      component.reviews
    end

    field :histories do |component, _options|
      component.histories
    end

    # Memberships via MembershipBlueprint (includes name, email from user)
    association :memberships, blueprint: MembershipBlueprint do |component, _options|
      component.memberships
    end

    field :metadata do |component, _options|
      component.metadata
    end

    association :inherited_memberships, blueprint: MembershipBlueprint do |component, _options|
      component.inherited_memberships
    end

    # available_members removed — now fetched via /api/users/search
    # to prevent information disclosure of the full user directory

    # all_users removed — PoC dropdown now uses /api/users/search?scope=members
    # to prevent pre-loading all team members into the DOM
  end
end
