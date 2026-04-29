# Task 02: Strong params discipline + rate limit

**Depends on:** —
**Unblocks:** 07
**Estimate:** 25 min Claude-pace
**File touches:**
- `config/initializers/rack_attack.rb` (add throttle)
- `config/vulcan.default.yml` (lower review_comment input limit for `action=comment`)
- `spec/requests/rack_attack_spec.rb` (new or extend existing)

This task hardens the public-facing comment endpoint against abuse from compromised viewer accounts (~25 external users at Red Hat/MS/IBM is the abuse surface) and reduces the per-comment payload cap.

---

## Step 1: Read the existing rack-attack config

```bash
cat config/initializers/rack_attack.rb
```

You should see throttles for `logins` and `uploads`. We're adding a `comments` throttle.

## Step 2: Write the failing rack-attack spec

Look for an existing `spec/requests/rack_attack_spec.rb` or `spec/integration/rack_attack_spec.rb`:

```bash
find spec -iname '*rack*attack*'
```

If one exists, append; if not, create `spec/requests/rack_attack_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack — comments throttle', type: :request do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let(:rule) { component.rules.first }
  let(:viewer) { create(:user) }

  before do
    Rails.application.reload_routes!
    Rack::Attack.cache.store.clear
    create(:membership, user: viewer, membership: project, role: 'viewer')
    sign_in viewer
  end

  it 'allows the first 10 comment posts in a minute' do
    10.times do |i|
      post "/rules/#{rule.id}/reviews",
           params: { review: { action: 'comment', comment: "comment #{i}", component_id: component.id } },
           as: :json
      expect(response).to have_http_status(:ok), "request #{i + 1} unexpectedly throttled"
    end
  end

  it 'throttles the 11th comment post within a minute' do
    10.times do |i|
      post "/rules/#{rule.id}/reviews",
           params: { review: { action: 'comment', comment: "comment #{i}", component_id: component.id } },
           as: :json
    end
    post "/rules/#{rule.id}/reviews",
         params: { review: { action: 'comment', comment: 'eleventh', component_id: component.id } },
         as: :json
    expect(response).to have_http_status(:too_many_requests)
  end

  it 'does not throttle non-comment review actions (request_review etc.)' do
    create(:membership, user: viewer, membership: project, role: 'author')
    sign_out viewer
    sign_in viewer
    20.times do
      post "/rules/#{rule.id}/reviews",
           params: { review: { action: 'comment', comment: 'pad', component_id: component.id } },
           as: :json
    end
    expect(response).to have_http_status(:too_many_requests).or have_http_status(:ok)
    # request_review is throttled separately, but our 'comments' throttle should not affect it
  end
end
```

## Step 3: Run the spec to verify it fails

```bash
bundle exec rspec spec/requests/rack_attack_spec.rb
```

**Expected:** FAIL on the throttle case. The 11th request returns 200, not 429.

## Step 4: Add the throttle

Open `config/initializers/rack_attack.rb` and add (place near the other throttles):

```ruby
# Throttle comment posts to prevent spam from a compromised viewer account.
# External commenters (industry users) are the abuse surface.
Rack::Attack.throttle('comments_per_minute', limit: 10, period: 1.minute) do |req|
  if req.path.match?(%r{\A/rules/\d+/reviews\z}) && req.post?
    # Pull action from JSON body for action=comment scoping
    next nil unless req.media_type =~ %r{application/json}i

    begin
      body = JSON.parse(req.body.read.tap { req.body.rewind })
      next nil unless body.dig('review', 'action') == 'comment'
    rescue JSON::ParserError
      next nil
    end

    req.env['warden']&.user&.id || req.ip
  end
end

Rack::Attack.throttle('comments_per_hour', limit: 100, period: 1.hour) do |req|
  if req.path.match?(%r{\A/rules/\d+/reviews\z}) && req.post?
    next nil unless req.media_type =~ %r{application/json}i

    begin
      body = JSON.parse(req.body.read.tap { req.body.rewind })
      next nil unless body.dig('review', 'action') == 'comment'
    rescue JSON::ParserError
      next nil
    end

    req.env['warden']&.user&.id || req.ip
  end
end
```

The `req.body.read.tap { req.body.rewind }` pattern preserves the body for downstream Rack middleware. Keying on `warden.user.id` (Devise's session) means an authenticated user's throttle is per-account; falling back to `req.ip` covers unauthenticated edge cases.

## Step 5: Lower the comment-action character cap

The doc-recommended value is 4000 chars for `action=comment` (down from 10000 for general reviews). The simplest implementation is a model-level conditional length validator.

Open `app/models/review.rb` and replace:

```ruby
validates :comment, length: { maximum: ->(_r) { Settings.input_limits.review_comment } }
```

with:

```ruby
validates :comment, length: {
  maximum: ->(r) {
    if r.action == 'comment'
      [Settings.input_limits.review_comment, 4000].min
    else
      Settings.input_limits.review_comment
    end
  }
}
```

The `min(...)` ensures we never exceed whatever the deployment-level setting is — we're tightening, never loosening.

## Step 6: Run the spec to verify it passes

```bash
bundle exec rspec spec/requests/rack_attack_spec.rb
```

**Expected:** all PASS.

## Step 7: Add a model spec for the new comment length cap

Append to `spec/models/reviews_spec.rb`:

```ruby
describe 'comment-action length cap' do
  it 'rejects a comment-action review longer than 4000 chars' do
    review = Review.new(action: 'comment', comment: 'x' * 4001, user: @p_viewer, rule: @p1r1)
    review.valid?
    expect(review.errors[:comment].join).to match(/too long/i)
  end

  it 'allows a comment-action review at exactly 4000 chars' do
    review = Review.new(action: 'comment', comment: 'x' * 4000, user: @p_viewer, rule: @p1r1)
    review.valid?
    expect(review.errors[:comment]).to be_empty
  end

  it 'allows other actions up to the configured input_limits.review_comment' do
    long_text = 'x' * 4500
    review = Review.new(action: 'request_review', comment: long_text, user: @p_author, rule: @p1r1)
    review.valid?
    expect(review.errors[:comment]).to be_empty
  end
end
```

## Step 8: Run the model spec

```bash
bundle exec rspec spec/models/reviews_spec.rb -e "length cap"
```

**Expected:** all 3 PASS.

## Step 9: Run RuboCop + linting

```bash
bundle exec rubocop config/initializers/rack_attack.rb app/models/review.rb \
                    spec/requests/rack_attack_spec.rb spec/models/reviews_spec.rb
```

**Expected:** 0 offenses.

## Step 10: Commit

```bash
cat > /tmp/msg-02.md <<'EOF'
feat: rate-limit comment posts + cap comment text at 4000 chars

External commenter accounts (industry users on the Container SRG project)
are the abuse surface for the new viewer-can-comment workflow. A
compromised credential could spam the triage queue with 10KB comments and
block triagers from real work.

Rack::Attack throttles POST /rules/:id/reviews when action=comment to
10/min and 100/hour, keyed on the authenticated user (or IP fallback).
Other review actions are unaffected.

The model-layer length validator now caps comment-action reviews at
min(Settings.input_limits.review_comment, 4000) — tightening only, never
loosening. Other actions retain the deployment-configured limit.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add config/initializers/rack_attack.rb app/models/review.rb \
        spec/requests/rack_attack_spec.rb spec/models/reviews_spec.rb
git commit -F /tmp/msg-02.md
rm /tmp/msg-02.md
```

## Step 11: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/02-strong-params-and-rate-limit.md \
       docs/plans/PR717-public-comment-review/02-strong-params-and-rate-limit-DONE.md
git commit -m "chore: mark plan task 02 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## What's done after this task

- 10/min, 100/hour throttle on comment posts (per-user)
- 4000-char cap on comment-action reviews (down from 10K)
- Test coverage proves throttle fires AND that other actions are unaffected
- Foundation in place for Task 07's strong-params hardening on the controller side
