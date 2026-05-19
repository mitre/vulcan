# frozen_string_literal: true

FactoryBot.define do
  factory :review do
    user
    rule
    action { 'request_review' }
    comment { 'Requesting review' }

    before(:create) do |review|
      next unless review.user && review.rule&.component&.project

      project = review.rule.component.project
      unless Membership.exists?(user: review.user, membership: project)
        role = Review::ACTION_PERMISSIONS[review.action] || :viewers
        min_role = Review::TIER_ROLES.fetch(role).first
        create(:membership, user: review.user, membership: project, role: min_role)
      end
    end

    # --- Comment traits ---

    trait :comment do
      action { 'comment' }
      section { 'check_content' }
      comment { 'Test comment on check content' }
    end

    trait :reply do
      action { 'comment' }
      comment { 'Reply to parent comment' }
      triage_status { nil }

      after(:build) do |review, _evaluator|
        unless review.responding_to_review_id
          parent = create(:review, :comment, user: review.user, rule: review.rule)
          review.responding_to_review_id = parent.id
          review.section = parent.section
        end
      end
    end

    trait :component_comment do
      action { 'comment' }
      rule { nil }
      section { nil }
      comment { 'Component-level comment' }

      after(:build) do |review|
        unless review.commentable_type == 'Component'
          component = create(:component, :skip_rules)
          review.commentable = component
          review.commentable_type = 'Component'

          if review.user
            project = component.project
            create(:membership, user: review.user, membership: project, role: 'viewer') unless Membership.exists?(user: review.user, membership: project)
          end
        end
      end
    end

    # --- Triage status traits ---

    trait :concur do
      triage_status { 'concur' }

      after(:build) do |review|
        review.triage_set_by ||= create(:user)
        review.triage_set_at ||= Time.current
      end
    end

    trait :non_concur do
      triage_status { 'non_concur' }

      after(:build) do |review|
        review.triage_set_by ||= create(:user)
        review.triage_set_at ||= Time.current
      end
    end

    trait :concur_with_comment do
      triage_status { 'concur_with_comment' }

      after(:build) do |review|
        review.triage_set_by ||= create(:user)
        review.triage_set_at ||= Time.current
      end
    end

    trait :needs_clarification do
      triage_status { 'needs_clarification' }

      after(:build) do |review|
        review.triage_set_by ||= create(:user)
        review.triage_set_at ||= Time.current
      end
    end

    trait :informational do
      triage_status { 'informational' }

      after(:build) do |review|
        review.triage_set_by ||= create(:user)
        review.triage_set_at ||= Time.current
      end
    end

    trait :withdrawn do
      triage_status { 'withdrawn' }

      after(:build) do |review|
        review.triage_set_by ||= review.user
        review.triage_set_at ||= Time.current
      end
    end

    trait :duplicate do
      triage_status { 'duplicate' }

      after(:build) do |review|
        review.triage_set_by ||= create(:user)
        review.triage_set_at ||= Time.current
        unless review.duplicate_of_review_id
          target = create(:review, :comment, rule: review.rule, user: review.user)
          review.duplicate_of_review_id = target.id
        end
      end
    end

    # --- Lifecycle traits ---

    trait :triaged do
      after(:build) do |review|
        review.triage_set_by ||= create(:user)
        review.triage_set_at ||= Time.current
      end
    end

    trait :adjudicated do
      after(:build) do |review|
        review.adjudicated_at ||= Time.current
        review.adjudicated_by ||= create(:user)
      end
    end
  end
end
