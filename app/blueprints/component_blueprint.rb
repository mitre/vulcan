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
  # Serializes a component's requirements, kind-routed to the blueprint that
  # can describe them: authored SrgRules go through their own, because
  # RuleBlueprint's views call methods only a Rule has.
  #
  # The preload plan comes from the blueprint about to render, rather than
  # being written out here, so it cannot drift from what that blueprint
  # actually reads — adding a field to a view carries its own data
  # requirement along with it. Preloading happens while this is still a
  # relation; the canonical ordering then runs in Ruby, where it has always
  # run, because sorting in SQL would hand row order to the database's
  # collation rules and quietly reorder requirements.
  # The requirement blueprint for a component's document kind — the ONE
  # blueprint-selection seam. Everything that serializes a component's
  # requirement rows (full collections here, filtered sets like the
  # in-component find) picks its blueprint through this method.
  def self.requirement_blueprint(component)
    component.document_type == 'srg' ? AuthoredSrgRuleBlueprint : RuleBlueprint
  end

  def self.serialized_requirements(component, options, view:)
    blueprint = requirement_blueprint(component)
    ordered = BaseRule.canonical_sort(component.requirements.preload_blueprint(blueprint, view))
    # The outer render's own view key must not override the nested view;
    # caller options (reaction summaries etc.) still pass through.
    blueprint.render_as_json(ordered, view: view, **options.except(:view, :view_name, :root, :meta))
  end

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

  # The kind-aware requirement count under the long-standing wire key:
  # srg components report their authored-row count, stig components the
  # class-Rule counter cache (which never sees authored rows). Included by
  # every view that serves the count so the value cannot fork per view.
  view :requirement_count do
    field :rules_count do |component, _options|
      component.requirements_count
    end
  end

  # === Latest view: dropdown population ===
  # Reference identity only — no per-record severity/comment queries.
  view :latest do
    fields :title
    excludes :based_on_title, :based_on_version, :severity_counts, :pending_comment_count
  end

  # === Summary view: lightweight header for SPA triage/settings routes ===
  # Identity + counts + srg info + effective_permissions + the serialized
  # comment-phase state machine. NO rules/reviews/histories arrays.
  # Phase booleans delegate to the model methods — the single source of
  # truth for the write-guards — never reimplemented here.
  view :summary do
    include_view :requirement_count
    fields :title, :released, :project_id, :component_id,
           :security_requirements_guide_id, :memberships_count,
           :updated_at, :comment_phase, :closed_reason, :document_type,
           :comment_period_starts_at, :comment_period_ends_at

    field :effective_permissions do |component, options|
      options[:current_user]&.effective_permissions(component)
    end

    field :accepting_new_comments do |component, _options|
      component.accepting_new_comments?
    end

    field :triaging_active do |component, _options|
      component.triaging_active?
    end

    field :frozen_for_writes do |component, _options|
      component.frozen_for_writes?
    end

    field :comment_period_days_remaining do |component, _options|
      component.comment_period_days_remaining
    end
  end

  # === Index view: listing page (ComponentCard) ===
  # Every field ComponentCard.vue reads must be present here or it
  # silently renders as undefined. Verified against grep of
  # component.X property access in ComponentCard.vue.
  view :index do
    include_view :requirement_count
    fields :updated_at, :released, :component_id, :project_id,
           :security_requirements_guide_id, :admin_name, :admin_email, :description,
           :document_type

    field :releasable do |component, _options|
      component.releasable
    end
  end

  # === Related view: related_rules parents (includes project for display name) ===
  view :related do
    fields :updated_at, :released

    field :project do |component, _options|
      ProjectBlueprint.render_as_json(component.project)
    end
  end

  # === Show view: non-member read-only ===
  view :show do
    fields :title, :description, :admin_name, :admin_email, :released, :updated_at, :document_type,
           :comment_phase, :closed_reason, :comment_period_starts_at, :comment_period_ends_at

    field :effective_permissions do |component, options|
      options[:current_user]&.effective_permissions(component)
    end

    field :rules do |component, options|
      ComponentBlueprint.serialized_requirements(component, options, view: :viewer)
    end

    # Component#reviews returns ReviewBlueprint-serialized hashes with
    # rule_displayed_name injected via options[:rule_names].
    field :reviews do |component, _options|
      component.reviews
    end
  end

  # === Editor view: full editing page ===
  view :editor do
    include_view :requirement_count
    # All DB columns needed by Vue components
    fields :title, :description, :admin_name, :admin_email,
           :released, :advanced_fields, :project_id, :component_id,
           :security_requirements_guide_id, :memberships_count,
           :updated_at, :created_at, :document_type,
           :comment_phase, :closed_reason, :comment_period_starts_at, :comment_period_ends_at

    field :effective_permissions do |component, options|
      options[:current_user]&.effective_permissions(component)
    end

    field :releasable do |component, _options|
      component.releasable
    end

    field :status_counts do |component, _options|
      component.status_counts
    end

    # Requirements that relocated OUT — a lifecycle fact from executed
    # relocation records, never one of the status buckets. Always 0 for
    # stig-kind components (relocation is SRG-authoring, source side).
    field :moved_out_count do |component, _options|
      component.moved_out_count
    end

    # Currency covers the WHOLE parent set: a dual-lineage component is
    # stale when ANY declared parent has a newer release. The latest_*
    # fields target the first stale parent (primary first).
    field :srg_is_latest do |component, _options|
      component.parents_current?
    end

    field :srg_latest_version do |component, _options|
      component.stale_parents.first&.latest_release&.version
    end

    field :srg_latest_id do |component, _options|
      component.stale_parents.first&.latest_release&.id
    end

    field :additional_questions do |component, _options|
      component.additional_questions.as_json
    end

    field :rules do |component, options|
      ComponentBlueprint.serialized_requirements(component, options, view: :editor)
    end

    # Component#reviews returns ReviewBlueprint-serialized hashes with
    # rule_displayed_name injected via options[:rule_names].
    field :reviews do |component, _options|
      component.reviews
    end

    field :histories do |component, _options|
      component.histories
    end

    # Memberships via MembershipBlueprint (includes name, email from user)
    association :memberships, blueprint: MembershipBlueprint do |component, _options|
      ApplicationRecord.sorted_by_id(component.memberships)
    end

    field :metadata do |component, _options|
      component.metadata
    end

    association :inherited_memberships, blueprint: MembershipBlueprint do |component, _options|
      ApplicationRecord.sorted_by_id(component.inherited_memberships)
    end

    # available_members removed — now fetched via /api/users/search
    # to prevent information disclosure of the full user directory

    # all_users removed — PoC dropdown now uses /api/users/search?scope=members
    # to prevent pre-loading all team members into the DOM
  end
end
