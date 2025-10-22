# Testing Guide

Comprehensive guide for testing Vulcan application code, including unit tests, integration tests, and system tests.

## Test Stack

- **RSpec** - Ruby testing framework
- **Capybara** - System/integration testing
- **FactoryBot** - Test data factories
- **SimpleCov** - Code coverage reporting
- **DatabaseCleaner** - Test database management
- **VCR** - HTTP interaction recording

## Prerequisites

Before running tests, ensure PostgreSQL is running and the test database is set up:

```bash
# 1. Start PostgreSQL (one-time, keeps running)
docker-compose -f docker-compose.dev.yml up -d

# 2. Create and migrate test database (one-time, or after schema changes)
bundle exec rails db:create RAILS_ENV=test
bundle exec rails db:migrate RAILS_ENV=test

# 3. Verify database is ready
docker-compose -f docker-compose.dev.yml ps
# Should show db service as "Up" and healthy
```

**Note:** The test suite uses a separate `vulcan_vue_test` database on the same PostgreSQL server as development. Tests will fail if PostgreSQL is not running.

## Running Tests

### Quick Commands

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/user_spec.rb:42

# Run tests with coverage
COVERAGE=true bundle exec rspec

# Run tests in parallel
PARALLEL_WORKERS=4 bundle exec rspec

# Run only failed tests
bundle exec rspec --only-failures

# Run tests matching pattern
bundle exec rspec -e "should validate presence"
```

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

  let(:user) { create(:user, password: 'password123') }

  scenario 'successful login' do
    visit root_path
    click_link 'Sign In'
    
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
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

### FactoryBot

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    confirmed_at { Time.now }

    trait :admin do
      admin { true }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    factory :admin_user, traits: [:admin]
  end
end
```

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
  adapter: postgresql
  database: vulcan_test
  pool: 5
  timeout: 5000
```

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

### VCR for HTTP Requests

```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  
  # Filter sensitive data
  config.filter_sensitive_data('<API_KEY>') { ENV['EXTERNAL_API_KEY'] }
end

# Usage in tests
describe 'GitHub Integration', vcr: true do
  it 'fetches user data' do
    # First run records the interaction
    # Subsequent runs use the cassette
    user = GitHubService.fetch_user('octocat')
    expect(user.login).to eq('octocat')
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

### N+1 Query Detection

```ruby
# Gemfile
group :test do
  gem 'bullet'
end

# spec/rails_helper.rb
if Bullet.enable?
  config.before(:each) do
    Bullet.start_request
  end

  config.after(:each) do
    Bullet.perform_out_of_channel_notifications if Bullet.notification?
    Bullet.end_request
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
        image: postgres:14
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
          ruby-version: 3.3.9
          bundler-cache: true
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '22'
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
        run: bundle exec rspec
      
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

## Resources

- [RSpec Documentation](https://rspec.info/)
- [Better Specs](http://www.betterspecs.org/)
- [Testing Rails Applications Guide](https://guides.rubyonrails.org/testing.html)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)