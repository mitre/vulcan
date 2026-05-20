# Testing Guide

Comprehensive guide for testing Vulcan application code, including unit tests, integration tests, and system tests.

## Test Stack

- **RSpec** - Ruby testing framework
- **Capybara** - System/integration testing
- **FactoryBot** - Test data factories
- **SimpleCov** - Code coverage reporting
- **DatabaseCleaner** - Test database management

## Running Tests

### Quick Commands

```bash
# Run all tests — use one of these (caps at 8 processors for stability)
rake spec:parallel                    # Rake task (recommended)
bin/parallel_rspec spec/              # Binstub alternative
bundle exec parallel_rspec spec/      # Direct (uses all CPUs — may be flaky)

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/user_spec.rb:42

# Run frontend tests
yarn test:unit

# Run tests with coverage
COVERAGE=true rake spec:parallel

# Run only failed tests
bundle exec rspec --only-failures

# Run tests matching pattern
bundle exec rspec -e "should validate presence"
```

> **Why 8 processors?** On 10-core machines, running 10 parallel rspec processes
> plus PostgreSQL causes CPU contention that produces flaky failures. The
> `rake spec:parallel` task and `bin/parallel_rspec` binstub cap at 8, leaving
> headroom for the database and OS.

### Test Types

```bash
# Unit tests only
bundle exec rspec spec/models spec/lib

# Request specs only
bundle exec rspec spec/requests

# System tests only
bundle exec rspec spec/system

# Run with specific tag
bundle exec rspec --tag focus
bundle exec rspec --tag ~slow  # Exclude slow tests
```

## Writing Tests

### Model Tests

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should have_secure_password }
  end

  describe 'associations' do
    it { should have_many(:projects).through(:memberships) }
    it { should have_many(:reviews) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_user) { create(:user, confirmed_at: Time.now) }
      let!(:inactive_user) { create(:user, confirmed_at: nil) }

      it 'returns only confirmed users' do
        expect(User.active).to include(active_user)
        expect(User.active).not_to include(inactive_user)
      end
    end
  end

  describe '#full_name' do
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns combined first and last name' do
      expect(user.full_name).to eq('John Doe')
    end
  end
end
```

### Request Specs (Rails 8)

```ruby
# spec/requests/projects_spec.rb
require 'rails_helper'

RSpec.describe 'Projects', type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before do
    # Required for Rails 8 lazy loading
    Rails.application.reload_routes!
  end

  describe 'GET /projects' do
    context 'when not authenticated' do
      it 'redirects to login' do
        get '/projects'
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated' do
      before { sign_in user }

      it 'returns success' do
        get '/projects'
        expect(response).to have_http_status(:success)
      end

      it 'displays projects' do
        project = create(:project, name: 'Test Project')
        create(:membership, user: user, project: project)
        
        get '/projects'
        expect(response.body).to include('Test Project')
      end
    end
  end

  describe 'POST /projects' do
    before { sign_in user }

    let(:valid_params) do
      { project: { name: 'New Project', description: 'Test' } }
    end

    it 'creates a new project' do
      expect {
        post '/projects', params: valid_params
      }.to change(Project, :count).by(1)
    end

    it 'redirects to project page' do
      post '/projects', params: valid_params
      expect(response).to redirect_to(project_path(Project.last))
    end
  end
end
```

### System Tests

```ruby
# spec/system/user_login_spec.rb
require 'rails_helper'

RSpec.describe 'User Login', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  let(:user) { create(:user, password: 'S3cure!#Pass001') }

  scenario 'successful login' do
    visit root_path
    click_link 'Sign In'

    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'S3cure!#Pass001'
    click_button 'Log in'
    
    expect(page).to have_content('Signed in successfully')
    expect(page).to have_link('Log Out')
  end

  scenario 'failed login with invalid credentials' do
    visit new_user_session_path
    
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'wrong_password'
    click_button 'Log in'
    
    expect(page).to have_content('Invalid Email or password')
    expect(page).not_to have_link('Log Out')
  end

  scenario 'user can reset password' do
    visit new_user_session_path
    click_link 'Forgot your password?'
    
    fill_in 'Email', with: user.email
    click_button 'Send reset instructions'
    
    expect(page).to have_content('You will receive an email')
  end
end
```

### JavaScript Component Tests

```javascript
// spec/javascript/components/ProjectCard.spec.js
import { shallowMount } from '@vue/test-utils'
import ProjectCard from '@/components/ProjectCard.vue'

describe('ProjectCard', () => {
  const project = {
    id: 1,
    name: 'Test Project',
    description: 'Test Description',
    members_count: 5
  }

  it('renders project name', () => {
    const wrapper = shallowMount(ProjectCard, {
      propsData: { project }
    })
    expect(wrapper.text()).toContain('Test Project')
  })

  it('emits edit event when edit button clicked', () => {
    const wrapper = shallowMount(ProjectCard, {
      propsData: { project }
    })
    wrapper.find('.edit-btn').trigger('click')
    expect(wrapper.emitted().edit).toBeTruthy()
    expect(wrapper.emitted().edit[0][0]).toEqual(project)
  })

  it('displays member count', () => {
    const wrapper = shallowMount(ProjectCard, {
      propsData: { project }
    })
    expect(wrapper.find('.members-count').text()).toBe('5 members')
  })
})
```

## Test Helpers

### FactoryBot — Available Traits

Vulcan factories are in `spec/factories/`. Every model that appears in seeds or tests has a factory with traits covering all real-world states.

#### User

```ruby
create(:user)                              # Basic confirmed user
create(:user, :admin)                      # Site admin
create(:user, :viewer, :with_membership)   # Viewer on auto-created project
create(:user, :author, :with_membership, project: my_project)  # Author on specific project
create(:user, :reviewer, :with_membership) # Reviewer
create(:ldap_user)                         # LDAP-authenticated user
```

#### Project

```ruby
create(:project)                           # Empty project
create(:project, :with_admin)              # Project with 1 admin membership
create(:project, :with_admin, admin_user: existing_user)  # Specific admin
create(:project, :with_members)            # All 4 role tiers (viewer/author/reviewer/admin)
```

#### Component

```ruby
create(:component)                         # Full component with SRG rules imported (~500ms)
create(:component, :skip_rules)            # Lightweight — no SRG rule import (fast)
create(:component, :skip_rules, :open_comment_period)  # Active comment window
create(:component, :skip_rules, :with_poc) # Has admin_name + admin_email
create(:component, :released)              # Released with all rules locked
```

#### Rule

```ruby
create(:rule)                              # Default: Not Yet Determined, unlocked
create(:rule, :locked)                     # Locked rule
create(:rule, :applicable_configurable)    # Status: Applicable - Configurable
create(:rule, :not_applicable)             # Status: Not Applicable
create(:rule, :not_yet_determined)         # Status: Not Yet Determined (explicit)
```

#### Membership

```ruby
create(:membership)                        # Default: viewer on a project
create(:membership, :viewer)               # Explicit viewer
create(:membership, :author)               # Author role
create(:membership, :reviewer)             # Reviewer role
create(:membership, :admin)                # Admin role
create(:membership, :for_component)        # Component-level membership
```

#### Review (comments, triage, workflow)

```ruby
# Comments
create(:review, :comment)                  # Top-level comment (auto-pending triage)
create(:review, :reply)                    # Reply linked to auto-created parent
create(:review, :component_comment)        # Comment on a Component (not a Rule)

# Triage statuses (compose with :comment)
create(:review, :comment, :concur)         # Triaged as concur
create(:review, :comment, :non_concur)     # Triaged as non-concur
create(:review, :comment, :concur_with_comment)
create(:review, :comment, :needs_clarification)
create(:review, :comment, :informational)  # Terminal — auto-adjudicated
create(:review, :comment, :withdrawn)      # Terminal — auto-adjudicated
create(:review, :comment, :duplicate)      # Terminal — requires duplicate_of target

# Lifecycle
create(:review, :comment, :triaged)        # Has triage_set_by + triage_set_at
create(:review, :comment, :concur, :adjudicated)  # Fully closed

# Workflow actions
create(:review)                            # Default: request_review action
```

> **Note:** The Review factory automatically creates a Membership linking the user
> to the rule's project with the minimum required role for the action. You don't
> need to manually wire up permissions in tests.

### Custom Matchers

```ruby
# spec/support/matchers/have_error_on.rb
RSpec::Matchers.define :have_error_on do |attribute|
  match do |model|
    model.valid?
    model.errors[attribute].present?
  end

  failure_message do |model|
    "expected #{model} to have error on #{attribute}"
  end
end
```

### Shared Examples

```ruby
# spec/support/shared_examples/authenticated_controller.rb
RSpec.shared_examples 'authenticated controller' do
  context 'when not authenticated' do
    it 'redirects to login' do
      action
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

# Usage
RSpec.describe ProjectsController do
  describe 'GET #index' do
    let(:action) { get :index }
    it_behaves_like 'authenticated controller'
  end
end
```

## Test Database

### Configuration

```yaml
# config/database.yml
test:
  <<: *default
  database: vulcan_vue_test<%= ENV['DB_SUFFIX'] %><%= ENV['TEST_ENV_NUMBER'] %>
```

`TEST_ENV_NUMBER` is set automatically by `parallel_tests` — each worker gets a suffix (blank, 2, 3, ..., N) creating databases `vulcan_vue_test`, `vulcan_vue_test2`, etc.

`DB_SUFFIX` is optional, used for worktree isolation (e.g., `_v2` → `vulcan_vue_test_v2`).

### Initial Setup (One-Time)

```bash
# 1. Ensure PostgreSQL is running (Docker or local)
docker compose up db -d

# 2. Create all parallel test databases
bundle exec rake parallel:create

# 3. Migrate the primary test database
bin/rails db:migrate RAILS_ENV=test

# 4. Load schema into all parallel databases
bundle exec rake parallel:load_schema
```

### After Schema Changes

When you add new migrations, parallel databases are **auto-synced**:

```bash
# This automatically runs parallel:prepare after migrating
bin/rails db:migrate

# Manual sync if needed
bundle exec rake parallel:prepare
```

> The `lib/tasks/parallel_sync.rake` hook runs `parallel:prepare` automatically
> after `db:migrate`, `db:reset`, and `db:schema:load`. You should never need
> to sync manually unless something goes wrong.

### Key Rake Tasks

| Task | Purpose |
|---|---|
| `parallel:create` | Create parallel test databases |
| `parallel:load_schema` | Load `db/schema.rb` into all parallel databases |
| `parallel:prepare` | Dump + load schema (requires migrated primary DB) |
| `parallel:migrate` | Run pending migrations on all parallel databases |
| `parallel:drop` | Drop all parallel test databases |

### Database Cleaner Setup

```ruby
# spec/support/database_cleaner.rb
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.around(:each, js: true) do |example|
    DatabaseCleaner.strategy = :truncation
    example.run
    DatabaseCleaner.strategy = :transaction
  end
end
```

## Test Coverage

### SimpleCov Configuration

```ruby
# spec/rails_helper.rb (at the top)
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/spec/'
    add_filter '/config/'
    add_filter '/vendor/'
    
    add_group 'Controllers', 'app/controllers'
    add_group 'Models', 'app/models'
    add_group 'Helpers', 'app/helpers'
    add_group 'Libraries', 'lib/'
    
    minimum_coverage 90
    minimum_coverage_by_file 80
  end
end
```

### Viewing Coverage

```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# Open in browser
open coverage/index.html

# Check coverage from command line
cat coverage/.last_run.json
```

## Mocking and Stubbing

### Basic Mocking

```ruby
describe 'ExternalService' do
  it 'calls external API' do
    # Mock external service
    allow(ExternalService).to receive(:fetch_data).and_return({ status: 'ok' })
    
    result = ExternalService.fetch_data
    expect(result[:status]).to eq('ok')
  end
end
```


## Performance Testing

### Benchmark Tests

```ruby
require 'benchmark'

describe 'Performance' do
  it 'processes large datasets efficiently' do
    time = Benchmark.realtime do
      1000.times { create(:project) }
      Project.all.each(&:calculate_metrics)
    end
    
    expect(time).to be < 5.0  # seconds
  end
end
```


## CI/CD Testing

### GitHub Actions Configuration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:18
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.9
          bundler-cache: true
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '24'
          cache: 'yarn'
      
      - name: Install dependencies
        run: |
          bundle install
          yarn install
      
      - name: Setup database
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
        run: |
          bundle exec rails db:create
          bundle exec rails db:schema:load
      
      - name: Run tests
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
          COVERAGE: true
        run: bundle exec parallel_rspec spec/

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/.resultset.json
```

## Best Practices

### Test Organization

1. **One assertion per test** (when practical)
2. **Descriptive test names** that explain the behavior
3. **Arrange-Act-Assert** pattern
4. **DRY with shared examples** and helpers
5. **Fast tests first**, slow tests last

### Test Data

1. **Use factories** instead of fixtures
2. **Minimal valid data** - only what's needed
3. **Avoid dependencies** between tests
4. **Clean state** between tests
5. **Meaningful test data** that reflects real usage

### XCCDF Seed Data

DISA STIG and SRG XCCDF XML files live in `db/seeds/` — this is the single source of truth used by both seeds and test factories:

```
db/seeds/
├── srgs/          # Security Requirements Guides (GPOS, Web Server, Container, Database)
└── stigs/         # STIGs (RHEL 9, Windows Server 2025, PostgreSQL, ASD)
```

- **Seeds** (`db/seeds.rb`) load all files from these directories to populate demo/review app databases
- **Factories** (`spec/factories/`) reference specific files for the `xml` column on Stig and SRG records
- **Model specs** that need to parse real XCCDF also reference these files directly

To update seed data, download new XCCDF ZIP files from [DISA STIG Library](https://public.cyber.mil/stigs/downloads/), extract the `*-xccdf.xml` file, and replace the corresponding file in `db/seeds/srgs/` or `db/seeds/stigs/`. Then update any hardcoded assertions in specs (e.g., rule counts) if the data changed.

### Test Performance

1. **Avoid hitting the database** when possible
2. **Use build/build_stubbed** instead of create
3. **Mock external services**
4. **Run tests in parallel** on CI
5. **Profile slow tests** and optimize

### Common Pitfalls

1. **Testing implementation** instead of behavior
2. **Brittle tests** that break with minor changes
3. **Slow test suite** that discourages running tests
4. **Missing edge cases** and error conditions
5. **Not testing the happy path** thoroughly

## Debugging Tests

### Interactive Debugging

```ruby
# Add in test
require 'pry'
binding.pry  # Execution stops here

# Or use byebug
require 'byebug'
byebug  # Execution stops here
```

### Save and Open Page

```ruby
# In system tests
save_and_open_page  # Opens browser with current state
save_and_open_screenshot  # Takes screenshot
```

### Test Logs

```ruby
# Enable logging in tests
Rails.logger.level = :debug

# Or for specific test
it 'does something' do
  Rails.logger.debug "Value: #{some_variable}"
  # test code
end
```

## Known Build Warnings

### PostCSS plugin deprecation (`postcss.plugin was deprecated`)

During `yarn build`, you will see warnings like:

```
trim: postcss.plugin was deprecated. Migration guide:
https://evilmartians.com/chronicles/postcss-8-plugin-migration
add-id: postcss.plugin was deprecated. Migration guide:
https://evilmartians.com/chronicles/postcss-8-plugin-migration
```

These come from `@vue/component-compiler-utils` which uses the legacy PostCSS 8 plugin API for Vue 2 SFC scoped style processing (the `trim` and `add-id` internal plugins). This package is end-of-life and will never be updated. The warnings are **build-time only with zero runtime impact**. They will disappear when the project migrates to Vue 3.

## Resources

- [RSpec Documentation](https://rspec.info/)
- [Better Specs](http://www.betterspecs.org/)
- [Testing Rails Applications Guide](https://guides.rubyonrails.org/testing.html)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)