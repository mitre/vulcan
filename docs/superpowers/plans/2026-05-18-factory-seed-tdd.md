# Vulcan Seed System Modernization — Full Implementation Plan

**Goal:** Transform the monolithic 648-line `db/seeds.rb` into a properly-structured seed pipeline following the GitLab/ThoughtBot two-concern pattern, with feature-complete factories, user-facing rake tasks, and verification specs.

**Why:** The current seed system has:
- A single monolithic file mixing production seeds with demo data
- 275+ hand-rolled `Review.create!` calls in tests (factory underutilized)
- Cross-project comments that duplicate on re-run (not idempotent)
- No user-facing commands for verify/status/reseed workflows
- Missing factories for Rule traits (locked, status), Project (with_admin), Component (comment_period)
- Seeds don't use factories at all — hand-roll everything
- No separation between production-required data and demo/dev data

**Audit date:** 2026-05-19. Full system review: all 14 factory files, 648 lines of seeds.rb, 8 rake tasks, seed_idempotency_spec, xccdf_seed_spec, docker-entrypoint, ENVIRONMENT_VARIABLES.md.

**Research:** Reviewed GitLab, Discourse, Mastodon, Chatwoot seed architectures. Evaluated seed-fu, seedbank, seed_dump, seed_migration, data_migrate, dibber, seedify gems. No actively-maintained seed gem fits our needs.

---

## Architecture Decision: GitLab/ThoughtBot Two-Concern Split

**Decision:** Separate production seeds from development demo data. No seed gem — modular Ruby files + FactoryBot in dev tasks.

**Industry evidence:**
- **GitLab**: Custom `DataSeeder` framework with FactoryBot for dev data; plain ActiveRecord in `db/seeds.rb` for production. FactoryBot only in `rake dev:prime` equivalent.
- **Discourse**: seed-fu fork (upstream unmaintained since 2018). Numbered files in `db/fixtures/`.
- **Mastodon**: `Dir[db/seeds/*.rb].sort.each { |f| load f }`. No gem.
- **Chatwoot**: Custom rake tasks in `lib/tasks/seed.rake`. No gem.
- **ThoughtBot** (FactoryBot creators): Explicitly recommend `rake dev:prime` for dev data, separate from `db:seeds.rb`. "Priming the pump" pattern.

**Why no seed gem:**
- seed-fu: Last release 2018. Unmaintained. Dead dependency in Rails 8.
- seedbank: Last release 2017. Same problem.
- seed_dump, data_migrate: Solve different problems (DB dump, versioned data migrations).
- All the major Rails apps use custom Ruby. The gems don't add value for complex domain seeds.

**What we build:**

```
Production seeds (db:seed)          Dev demo data (dev:prime)
├── SRG/STIG XML imports            ├── Demo users (FactoryBot)
├── Admin bootstrap                 ├── Demo projects + memberships
└── Reference data                  ├── Demo components + rules
                                    ├── Demo comments + triage
                                    └── Cross-project scenarios
```

### File layout

```
db/
├── seeds.rb                          # Thin loader — loads db/seeds/data/*.rb
└── seeds/
    └── data/
        ├── 00_users.rb               # Admin + role-tier users (prod + dev)
        ├── 01_projects.rb            # Demo projects
        ├── 02_srgs.rb                # SRG XML imports (production-essential)
        ├── 03_stigs.rb               # STIG XML imports (production-essential)
        ├── 04_components.rb          # Named + overlay + dummy components
        ├── 05_memberships.rb         # User → Project RBAC wiring
        ├── 06_rule_statuses.rb       # Varied statuses for demo coverage
        ├── 10_comments.rb            # Container Platform comments (FactoryBot)
        └── 11_cross_project.rb       # Cross-project comments (FactoryBot)
    └── srgs/                         # (existing) XML files
    └── stigs/                        # (existing) XML files

lib/
├── seed_helpers.rb                   # Shared helpers: seed_xccdf, seed_component, etc.
└── tasks/
    └── dev.rake                      # dev:prime, dev:reset, dev:verify, dev:status
```

### User-facing commands

| Command | Purpose | When |
|---------|---------|------|
| `rails db:seed` | Load all seed data (prod + dev gated by env) | Initial setup |
| `rails dev:prime` | Load/refresh demo data using FactoryBot | Dev setup, after schema change |
| `rails dev:reset` | Clear demo data + re-prime | Start fresh |
| `rails dev:verify` | Check seed data completeness + consistency | After seed, CI |
| `rails dev:status` | Report what's seeded (counts per model) | Diagnostics |

---

## Dependency Graph

```
Task 1: Feature-complete factories (ALL models)
    ↓
Task 2: Seed helpers + modular layout + rake tasks
    ↓
Task 3: Rewrite all seed files (prod + dev split)
    ↓
Task 4: Functional verification spec + test migration
    ↓
Task 5: Integration — full pipeline end-to-end
```

---

## Task 1: Feature-Complete Factories — ALL Models (sp:5, ~35 min)

Every model that appears in seeds or tests needs a factory covering all its real-world states. The factory system is the foundation — everything else builds on it.

### Review factory (DONE)
- ✅ `:comment`, `:reply`, `:component_comment`
- ✅ `:concur`, `:non_concur`, `:concur_with_comment`, `:needs_clarification`
- ✅ `:informational`, `:withdrawn`, `:duplicate`
- ✅ `:triaged`, `:adjudicated`
- ✅ Auto-membership wiring in `after(:build)`

### Rule factory (needs traits)
```ruby
trait :locked do
  locked { true }
end

trait :applicable_configurable do
  status { 'Applicable - Configurable' }
end

trait :not_applicable do
  status { 'Not Applicable' }
end

trait :not_yet_determined do
  status { 'Not Yet Determined' }  # already the default, but explicit is better
end

trait :under_review do
  association :review_requestor, factory: :user
end
```

### Project factory (needs traits)
```ruby
trait :with_admin do
  transient { admin_user { nil } }
  after(:create) do |project, eval|
    user = eval.admin_user || create(:user)
    create(:membership, :admin, user: user, membership: project)
  end
end

trait :with_members do
  transient { member_roles { %w[viewer author reviewer admin] } }
  after(:create) do |project, eval|
    eval.member_roles.each do |role|
      create(:membership, user: create(:user), membership: project, role: role)
    end
  end
end
```

### Component factory (needs traits)
```ruby
trait :open_comment_period do
  comment_phase { 'open' }
  comment_period_starts_at { 1.day.ago }
  comment_period_ends_at { 14.days.from_now }
end

trait :closed_comment_period do
  comment_phase { 'final' }
  comment_period_starts_at { 30.days.ago }
  comment_period_ends_at { 1.day.ago }
end

trait :with_poc do
  admin_name { 'Test Maintainer' }
  admin_email { 'maintainer@example.com' }
end

trait :released do
  released { true }
  after(:create) { |c| c.rules.update_all(locked: true) }
end
```

### Membership factory
- Already good. Add explicit `:viewer` trait for symmetry.

### Files
- Modify: `spec/factories/rules.rb`, `projects.rb`, `components.rb`, `memberships.rb`
- Already done: `spec/factories/reviews.rb`
- Already done: `spec/factories/review_traits_spec.rb`
- Verify: `spec/factories_spec.rb` (auto-tests all traits)

### First failing test
`expect(build(:rule, :locked).locked).to eq(true)` — no trait exists yet.

### Verification
```bash
bundle exec rspec spec/factories_spec.rb spec/factories/review_traits_spec.rb
```

---

## Task 2: Seed Helpers + Modular Layout + Rake Tasks (sp:5, ~35 min)

Build the infrastructure before migrating content. This is the skeleton that all seed files plug into.

### lib/seed_helpers.rb — Shared module
```ruby
# frozen_string_literal: true

module SeedHelpers
  DEMO_PASSWORD = ENV.fetch('VULCAN_SEED_ADMIN_PASSWORD', '12qwaszx!@QWASZX')
  DEMO_EMAILS = %w[admin@example.com viewer@example.com author@example.com reviewer@example.com].freeze

  # Parse XCCDF XML and create SRG or STIG record.
  # Idempotent: skips if srg_id/stig_id already exists.
  def self.seed_xccdf(filepath)
    # (extracted from current seeds.rb lines 64-96)
  end

  # Find or create a component with all required attributes.
  # Idempotent via find_or_initialize_by(project, name, version, release).
  def self.seed_component(**opts)
    # (extracted from current seeds.rb lines 201-220)
  end

  # Idempotent review creation. Finds by comment text, or creates via FactoryBot.
  def self.find_or_seed_review(trait = :comment, **attrs)
    Review.find_by(action: 'comment', comment: attrs[:comment]) ||
      FactoryBot.create(:review, trait, **attrs)
  end

  # Idempotent reply creation. Finds by parent + comment text.
  def self.find_or_seed_reply(parent:, user:, comment:)
    Review.find_by(responding_to_review_id: parent.id, comment: comment) ||
      FactoryBot.create(:review, :reply, user: user, rule: parent.rule,
                        responding_to_review_id: parent.id, section: parent.section,
                        comment: comment)
  end

  # Report seed data counts for diagnostics.
  def self.status_report
    {
      users: User.count,
      projects: Project.count,
      srgs: SecurityRequirementsGuide.count,
      stigs: Stig.count,
      components: Component.count,
      rules: BaseRule.where(type: 'Rule').count,
      memberships: Membership.count,
      comments: Review.where(action: 'comment').count,
      replies: Review.where(action: 'comment').where.not(responding_to_review_id: nil).count
    }
  end

  # Verify seed data meets minimum requirements.
  def self.verify!
    errors = []
    errors << "No admin user" unless User.exists?(admin: true)
    errors << "No projects (expected >= 4)" unless Project.count >= 4
    errors << "No SRGs" unless SecurityRequirementsGuide.count >= 1
    errors << "No components" unless Component.count >= 4
    # ... more checks
    errors
  end
end
```

### lib/tasks/dev.rake — User-facing commands
```ruby
namespace :dev do
  desc 'Load demo data using FactoryBot (idempotent, safe to run multiple times)'
  task prime: :environment do
    require_relative '../../lib/seed_helpers'
    Rake::Task['db:seed'].invoke
  end

  desc 'Clear demo data and re-prime'
  task reset: :environment do
    # Delete ONLY demo data (by known patterns), not user-created content
  end

  desc 'Verify seed data completeness and consistency'
  task verify: :environment do
    require_relative '../../lib/seed_helpers'
    errors = SeedHelpers.verify!
    if errors.empty?
      puts "✅ All seed data verified"
    else
      errors.each { |e| puts "❌ #{e}" }
      exit 1
    end
  end

  desc 'Report seed data status (record counts per model)'
  task status: :environment do
    require_relative '../../lib/seed_helpers'
    SeedHelpers.status_report.each { |model, count| puts "  #{model}: #{count}" }
  end
end
```

### db/seeds.rb — Thin loader
```ruby
# frozen_string_literal: true

unless Rails.env.local? || ENV['VULCAN_SEED_DEMO_DATA'] == 'true'
  puts 'Skipping seed data (set VULCAN_SEED_DEMO_DATA=true for demo data)'
  return
end

require_relative '../lib/seed_helpers'

Dir.glob(Rails.root.join('db/seeds/data/*.rb')).sort.each do |seed_file|
  puts "\n=== #{File.basename(seed_file)} ==="
  load(seed_file)
end

puts "\n✅ Seed complete. Run `rails dev:verify` to check data, `rails dev:status` for counts."
```

### Files
- Create: `lib/seed_helpers.rb`
- Create: `lib/tasks/dev.rake`
- Create: `db/seeds/data/` directory
- Modify: `db/seeds.rb` (becomes thin loader)

### First failing test
`expect { Rake::Task['dev:verify'].invoke }.not_to raise_error`

### Verification
```bash
rails dev:status
rails dev:verify
```

---

## Task 3: Rewrite All Seed Files — Prod + Dev Split (sp:8, ~60 min)

Migrate each section of the monolithic seeds.rb into its numbered file. Use FactoryBot for demo data. Fix all idempotency gaps. One file at a time — verify after each.

### 00_users.rb
- Admin: conditional `User.exists?(admin: true)` (production-safe)
- Role-tier users: `find_or_initialize_by(email:)` (existing pattern, already correct)
- Filler users: count-gated, FFaker names

### 01_projects.rb
- `Project.find_or_create_by!(name:)` (existing pattern, already correct)

### 02_srgs.rb
- `SeedHelpers.seed_xccdf(filepath)` for each XML in `db/seeds/srgs/`
- Idempotent via `find_by(srg_id:)` (existing, already correct)

### 03_stigs.rb
- `SeedHelpers.seed_xccdf(filepath)` for each XML in `db/seeds/stigs/`
- Idempotent via `find_by(stig_id:)` (existing, already correct)

### 04_components.rb
- Named components via `SeedHelpers.seed_component`
- Overlay components with conditional rule duplication
- Dummy "Nothing to See Here" components (count-gated)
- PoC backfill
- **Keep custom Ruby** — SRG FK + auto-rule-import doesn't fit factories

### 05_memberships.rb
- All users → all projects
- Role-tier upgrades (viewer→assigned role)
- Counter cache reset
- **This is the RBAC wiring — explicit, auditable, idempotent**

### 06_rule_statuses.rb
- Set varied statuses on specific rules for demo coverage
- Must run AFTER components (rules auto-created from SRG)

### 10_comments.rb (Container Platform)
- **USE FactoryBot:** `SeedHelpers.find_or_seed_review(:comment, rule: rule, comment: '...')`
- Content-aware text referencing actual rule content
- Reply threading via `:reply` trait
- Triage decisions via `:concur`, `:withdrawn`, etc.
- **FIX:** All creation goes through idempotent helpers

### 11_cross_project.rb
- **FIX IDEMPOTENCY BUG:** Currently uses bare `Review.create!` — DUPLICATES on re-run
- Wrap in `SeedHelpers.find_or_seed_review` or `unless Review.exists?(...)`
- Use FactoryBot traits for triage status composition

### Files
- Create: 9 files in `db/seeds/data/`
- Modify: `db/seeds.rb` (remove all content, becomes loader)
- Modify: `lib/seed_helpers.rb` (add extracted helpers)

### First failing test
Run `rails db:seed` twice — cross-project comments should NOT duplicate.

### Verification
```bash
rails db:seed && rails dev:verify
rails db:seed && rails dev:verify  # second run — same counts
```

---

## Task 4: Functional Seed Verification Spec + Test Migration (sp:8, ~60 min)

Two sub-goals: (A) functional spec that RUNS seeds and checks data, (B) migrate test files from hand-rolled Review.create! to factory calls.

### A. Functional seed spec
```ruby
# spec/seeds/seed_pipeline_spec.rb
RSpec.describe 'seed pipeline', type: :seed do
  before(:all) { Rails.application.load_seed }

  it { expect(User.count).to be >= 14 }
  it { expect(Project.count).to eq(5) }
  it { expect(SecurityRequirementsGuide.count).to eq(4) }
  it { expect(Stig.count).to eq(4) }
  it { expect(Component.count).to be >= 8 }

  it 'RBAC: every demo project has all role tiers' do
    Project.where(name: ['Photon 3', 'Photon 4', 'vSphere 7.0', 'Container Platform']).each do |p|
      roles = p.memberships.pluck(:role).uniq
      expect(roles).to include('viewer', 'author', 'reviewer', 'admin')
    end
  end

  it 'comments: expected count + triage coverage' do
    comments = Review.where(action: 'comment', responding_to_review_id: nil)
    expect(comments.count).to be >= 18
    statuses = comments.distinct.pluck(:triage_status).compact
    expect(statuses).to include('pending', 'concur', 'non_concur', 'informational', 'withdrawn')
  end

  it 'idempotent: second run does not duplicate records' do
    before = SeedHelpers.status_report
    Rails.application.load_seed
    after = SeedHelpers.status_report
    expect(after).to eq(before)
  end
end
```

### B. Test file migration (275+ Review.create! → factory)
Target files by priority:
1. `spec/blueprints/rule_blueprint_spec.rb` (13 calls)
2. `spec/models/project_pending_comment_counts_spec.rb` (8 calls)
3. `spec/models/reaction_spec.rb` (3 calls)
4. `spec/models/query_performance_spec.rb` (3 calls)
5. `spec/blueprints/review_membership_blueprints_spec.rb` (3 calls)
6. Remaining files (grep-driven)

**Approach:** One file at a time. Update, run that file's tests, verify green. Never change assertions — only change how records are created. Full suite at the end.

### Files
- Create: `spec/seeds/seed_pipeline_spec.rb`
- Keep: `spec/config/seed_idempotency_spec.rb` (static analysis)
- Modify: 5+ spec files with hand-rolled Review.create!

### First failing test
Idempotency test — cross-project comments currently duplicate.

### Verification
```bash
bundle exec rspec spec/seeds/ && bundle exec rake spec:parallel
```

---

## Task 5: Integration — Full Pipeline End-to-End (sp:3, ~20 min)

Final verification pass. Everything wired together.

### Checklist
- [ ] `rails db:drop db:create db:migrate db:seed` — clean run
- [ ] `rails db:seed` second time — idempotent, no duplicates
- [ ] `rails dev:verify` — all checks pass
- [ ] `rails dev:status` — expected counts
- [ ] `rails dev:reset` — clears and re-primes
- [ ] `bundle exec rspec spec/seeds/` — functional spec green
- [ ] `bundle exec rspec spec/factories_spec.rb` — all factories + traits green
- [ ] `bundle exec rake spec:parallel` — full suite green
- [ ] Manual browser test: login as each role, verify demo data visible
- [ ] CHANGELOG entry

### Files
- No new files — integration of Tasks 1-4
- Modify: `CHANGELOG.md`

### Verification
```bash
rails db:drop db:create db:migrate db:seed && rails dev:verify && bundle exec rake spec:parallel
```

---

## Estimated Total

| Task | SP | Claude-pace | What |
|------|----|-------------|------|
| 1 | 5 | ~35 min | Feature-complete factories (all models) |
| 2 | 5 | ~35 min | Seed helpers + modular layout + rake tasks |
| 3 | 8 | ~60 min | Rewrite all seed files (prod/dev split) |
| 4 | 8 | ~60 min | Verification spec + test migration |
| 5 | 3 | ~20 min | Integration — full pipeline E2E |
| **Total** | **29** | **~210 min** | |

---

## Out of Scope

- Docker entrypoint changes (db:prepare stays as-is; demo data is opt-in)
- Frontend test fixtures (different data shape)
- STIG/SRG puller refactoring (already has its own idempotent rake task)
- seed-fu or any seed management gem (rejected — see Architecture Decision)
- Production deployment seed strategy (uses admin:bootstrap, not demo data)
- data_migrate gem (solves versioned data migrations, different problem)
