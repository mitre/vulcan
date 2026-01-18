# Testing & Quality Checklist

**Purpose:** Ensure every phase meets quality standards before moving to next
**Approach:** Test thoroughly, fix completely, commit cleanly

---

## Quality Gates (Every Phase)

Before marking ANY phase complete, ALL must be ✅:

### Automated Testing
- [ ] All RSpec tests pass (no failures, no pending)
- [ ] New tests added for new functionality
- [ ] Test coverage >90% for new code
- [ ] RuboCop clean (0 offenses): `bundle exec rubocop`
- [ ] Brakeman clean (0 security issues): `bundle exec brakeman`
- [ ] No N+1 queries: `BULLET=true bundle exec rspec`
- [ ] ESLint clean: `yarn lint` (if JS changes)

### Manual Testing
- [ ] Feature works in browser
- [ ] Edge cases tested
- [ ] Error handling works
- [ ] UI displays correctly
- [ ] No console errors

### Code Review
- [ ] Code is readable and well-organized
- [ ] No duplication
- [ ] Follows established patterns
- [ ] Properly documented
- [ ] No TODOs or FIXMEs

### Documentation
- [ ] PROGRESS.md updated
- [ ] Comments added where needed
- [ ] README updated if public API changed
- [ ] CLAUDE.md updated if patterns changed

### Git Hygiene
- [ ] Changes committed with clear message
- [ ] Commit message follows convention (feat:, fix:, refactor:, test:)
- [ ] Authored by: Aaron Lippold<lippold@gmail.com>
- [ ] No unrelated changes in commit

---

## Phase-Specific Testing

### PHASE 1: Database Redesign

#### Migration Testing
```bash
# Test migration
bundle exec rails db:migrate
bundle exec rails db:rollback
bundle exec rails db:migrate

# Verify schema
bundle exec rails db:schema:dump
git diff db/schema.rb
```

#### Data Migration Testing
```ruby
# In rails console or test script
# Before migration:
component = Component.first
puts "Rules: #{component.rules.count}"  # Should be 264

# Run data migration
bundle exec rake data:migrate_satisfactions

# After migration:
component.reload
puts "Rules: #{component.rules.count}"  # Should be 13
puts "Satisfied: #{component.satisfied_srg_requirements.count}"  # Should be 251
```

#### Manual Checklist
- [ ] Migration runs without errors
- [ ] Data migration preserves all relationships
- [ ] Component rule counts correct (13 not 264)
- [ ] Satisfaction counts correct (251)
- [ ] UI component cards show correct numbers
- [ ] Import XCCDF creates 13 rules (not 264)
- [ ] Import spreadsheet creates 13 rules (not 264)
- [ ] Export → Import preserves data

#### SQL Verification
```sql
-- Check no duplicate SRG rules remain
SELECT c.id, c.name, COUNT(r.id) as rule_count,
       COUNT(CASE WHEN r.type = 'SrgRule' THEN 1 END) as srg_rule_count
FROM components c
LEFT JOIN base_rules r ON r.component_id = c.id
GROUP BY c.id, c.name
HAVING COUNT(CASE WHEN r.type = 'SrgRule' THEN 1 END) > 0;
-- Should return 0 rows

-- Check satisfaction counts
SELECT r.id, r.version, COUNT(s.srg_rule_id) as satisfaction_count
FROM base_rules r
LEFT JOIN component_srg_satisfactions s ON s.rule_id = r.id
WHERE r.component_id = [component_id]
GROUP BY r.id, r.version;
```

---

### PHASE 2: Service Objects

#### Service Testing
```bash
# Run service specs
bundle exec rspec spec/services/

# Check coverage
COVERAGE=true bundle exec rspec spec/services/
# Should be 100%
```

#### Integration Testing
```ruby
# Test import via service matches old behavior
old_component = Component.create!(name: 'Old')
old_component.from_xccdf(file)  # Old way

new_component = Component.create!(name: 'New')
Imports::XccdfImportService.call(new_component, file)  # New way

# Compare results
expect(new_component.rules.count).to eq(old_component.rules.count)
expect(new_component.rules.pluck(:version).sort).to eq(
  old_component.rules.pluck(:version).sort
)
```

#### Manual Checklist
- [ ] Import XCCDF via service works
- [ ] Import spreadsheet via service works
- [ ] Export XCCDF via service works
- [ ] Export CSV via service works
- [ ] Duplicate component via service works
- [ ] All services have error handling
- [ ] All services return consistent results
- [ ] Component model <450 LOC
- [ ] Controllers delegate to services cleanly

---

### PHASE 3: Pundit Authorization

#### Policy Testing
```bash
# Run policy specs
bundle exec rspec spec/policies/

# Check coverage
COVERAGE=true bundle exec rspec spec/policies/
# Should be 100%
```

#### Authorization Testing
```ruby
# Test all roles
admin_user = create(:user, admin: true)
author_user = create(:user)
viewer_user = create(:user)

component = create(:component)

# Admin can do everything
expect(ComponentPolicy.new(admin_user, component)).to permit_actions(
  [:show, :edit, :update, :destroy]
)

# Author can edit
expect(ComponentPolicy.new(author_user, component)).to permit_actions(
  [:show, :edit, :update]
)
expect(ComponentPolicy.new(author_user, component)).to forbid_action(:destroy)

# Viewer can only view
expect(ComponentPolicy.new(viewer_user, component)).to permit_action(:show)
expect(ComponentPolicy.new(viewer_user, component)).to forbid_actions(
  [:edit, :update, :destroy]
)
```

#### Manual Checklist
- [ ] Admin can access everything
- [ ] Author can edit but not destroy
- [ ] Viewer can only view
- [ ] Non-members blocked
- [ ] Unauthorized redirects to root with flash
- [ ] ApplicationController <120 LOC
- [ ] User model has no permission methods
- [ ] All controllers use `authorize`

---

### PHASE 4: Query Objects

#### Performance Testing
```bash
# Run with Bullet
BULLET=true bundle exec rspec

# Should show no N+1 warnings
```

#### Benchmark Testing
```ruby
require 'benchmark'

component = Component.first

# Old way
old_time = Benchmark.realtime do
  100.times { component.rules_summary }
end

# New way
new_time = Benchmark.realtime do
  100.times { ComponentRulesSummaryQuery.call(component) }
end

puts "Old: #{old_time}s"
puts "New: #{new_time}s"
puts "Improvement: #{((old_time - new_time) / old_time * 100).round(1)}%"
# Should be 40-60% faster
```

#### Manual Checklist
- [ ] rules_summary uses query object
- [ ] Query count reduced (10+ → 2-3)
- [ ] No N+1 queries detected
- [ ] Performance improved 40-60%
- [ ] Results match old implementation
- [ ] Query objects tested in isolation

---

### PHASE 5: Blueprinter Serialization

#### Blueprint Testing
```bash
# Run blueprint specs
bundle exec rspec spec/blueprints/

# Check JSON structure
```

#### JSON Validation
```ruby
# Verify JSON structure matches
component = create(:component_with_rules)

# Old way
old_json = component.to_json(methods: [:primary_controls_count])
old_hash = JSON.parse(old_json)

# New way
new_json = ComponentBlueprint.render(component, view: :detail)
new_hash = JSON.parse(new_json)

# Compare keys
expect(new_hash.keys.sort).to eq(old_hash.keys.sort)
```

#### Manual Checklist
- [ ] All endpoints return JSON
- [ ] List views exclude associations
- [ ] Detail views include associations
- [ ] Nested associations work
- [ ] All `as_json` methods removed from models
- [ ] Blueprint views tested

---

### PHASE 6: Full API

#### API Testing
```bash
# Run API specs
bundle exec rspec spec/requests/api/

# Generate Swagger docs
bundle exec rake rswag:specs:swaggerize

# View docs at http://localhost:3000/api-docs
```

#### Authentication Testing
```ruby
# Test token authentication
user = create(:user)
token = user.api_token

# Authorized request
get '/api/v1/components',
    headers: { 'Authorization' => "Bearer #{token}" }
expect(response).to have_http_status(:ok)

# Unauthorized request
get '/api/v1/components'
expect(response).to have_http_status(:unauthorized)
```

#### Rate Limiting Testing
```ruby
# Test rate limits
100.times do
  get '/api/v1/components', headers: auth_headers
  expect(response).to have_http_status(:ok)
end

# 101st request should be throttled
get '/api/v1/components', headers: auth_headers
expect(response).to have_http_status(:too_many_requests)
```

#### Manual Checklist
- [ ] All CRUD operations work via API
- [ ] Token authentication enforced
- [ ] Invalid tokens rejected
- [ ] Rate limiting enforced
- [ ] CORS headers present
- [ ] Swagger docs complete
- [ ] All endpoints documented
- [ ] Error responses consistent

---

### PHASE 7: Update from File

#### Update Testing
```ruby
# Export component
component = create(:component_with_rules)
xccdf = Exports::XccdfExportService.call(component)

# Modify XCCDF (change a title)
modified_xccdf = xccdf.gsub('Original Title', 'Modified Title')

# Update from modified file
service = Imports::XccdfImportService.new(component, modified_xccdf)
service.update(component, modified_file)

# Verify update
expect(component.rules.first.title).to eq('Modified Title')
expect(component.rules.count).to eq(13) # Count unchanged
```

#### Manual Checklist
- [ ] Export XCCDF
- [ ] Edit in external tool
- [ ] Update from file works
- [ ] Changes reflected
- [ ] Unchanged data preserved
- [ ] New rules can be added
- [ ] Works for spreadsheets too

---

### PHASE 8: Project Backup/Restore

#### Roundtrip Testing
```ruby
# Create test project
original = create(:project_with_components, component_count: 3)
original_component_count = original.components.count
original_rule_count = original.components.sum { |c| c.rules.count }

# Backup
backup_zip = Projects::BackupService.call(original)

# Restore
restored = Projects::RestoreService.call(backup_zip, user)

# Verify identical
expect(restored.name).to eq(original.name)
expect(restored.components.count).to eq(original_component_count)
expect(restored.components.sum { |c| c.rules.count }).to eq(original_rule_count)
```

#### Cross-Instance Testing
- [ ] Export from production Vulcan
- [ ] Import to development Vulcan
- [ ] Verify all data present
- [ ] Verify all relationships intact

#### Manual Checklist
- [ ] Backup creates valid ZIP
- [ ] ZIP contains all components as XCCDF
- [ ] ZIP contains metadata
- [ ] ZIP contains memberships
- [ ] Restore creates project
- [ ] All components imported
- [ ] All rules present
- [ ] Memberships restored

---

## Daily Testing Routine

### Every Morning (Before Starting)
```bash
# Ensure clean slate
git status  # Should be clean
bundle exec rspec  # All tests pass
bundle exec rubocop  # No offenses
```

### During Development
```bash
# Run relevant tests frequently
bundle exec rspec spec/services/  # If working on services
bundle exec rspec spec/policies/  # If working on policies

# Check for N+1s
BULLET=true bundle exec rspec spec/requests/
```

### Before Every Commit
```bash
# Full quality check
bundle exec rspec  # All tests
bundle exec rubocop --autocorrect-all  # Fix style
bundle exec brakeman  # Security scan
yarn lint  # JS/Vue linting

# All must be clean before commit
```

### End of Day
```bash
# Full test suite
bundle exec rspec

# Update progress
# Update PROGRESS.md with what's complete
```

---

## Test Coverage Targets

### By Test Type
- **Services:** 100% coverage (no exceptions)
- **Policies:** 100% coverage (test all roles)
- **Query Objects:** 100% coverage (test all paths)
- **Blueprints:** 95% coverage (test all views)
- **API Controllers:** 95% coverage (test all endpoints)
- **Models:** 85% coverage (existing)
- **Overall:** >90% coverage

### Coverage Tools
```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# View in browser
open coverage/index.html
```

---

## Performance Testing

### Before Each Phase
```ruby
# Baseline benchmark
component = Component.first
Benchmark.realtime { component.rules_summary }
```

### After Each Phase
```ruby
# Compare benchmark
component = Component.first
Benchmark.realtime { ComponentRulesSummaryQuery.call(component) }
```

### N+1 Detection
```bash
# Development mode
BULLET=true bundle exec rails s

# Test mode
BULLET=true bundle exec rspec

# Check for warnings in log
```

---

## Regression Testing

### Critical Workflows (Test After Every Phase)
1. **User Registration/Login**
   - [ ] Register new user
   - [ ] Login with email/password
   - [ ] Login with GitHub
   - [ ] Login with OIDC

2. **Project Management**
   - [ ] Create project
   - [ ] Add members
   - [ ] Update project settings
   - [ ] Delete project

3. **Component Import**
   - [ ] Import from XCCDF
   - [ ] Import from spreadsheet
   - [ ] Verify rule counts
   - [ ] Verify satisfaction relationships

4. **Component Export**
   - [ ] Export to XCCDF
   - [ ] Export to CSV
   - [ ] Verify data complete

5. **Rule Editing**
   - [ ] Create new rule
   - [ ] Edit rule fields
   - [ ] Add satisfactions
   - [ ] Save changes

6. **Review Workflow**
   - [ ] Request review
   - [ ] Approve review
   - [ ] Lock control

---

## Security Testing

### After Phases 3 & 6 (Authorization & API)
```bash
# Security scan
bundle exec brakeman --run-all-checks

# Should be clean (0 warnings)
```

### Manual Security Checks
- [ ] Unauthorized users blocked from editing
- [ ] API requires authentication
- [ ] Rate limiting prevents abuse
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] CSRF protection enabled
- [ ] Secure token generation

---

## Integration Testing

### Import/Export Roundtrip (After Every Import/Export Change)
```ruby
# XCCDF roundtrip
original = create(:component_with_rules)
xccdf = Exports::XccdfExportService.call(original)

new_component = Component.new
Imports::XccdfImportService.call(new_component, xccdf)

expect(new_component.rules.count).to eq(original.rules.count)
expect(new_component.satisfied_srg_requirements.count).to eq(
  original.satisfied_srg_requirements.count
)

# Spreadsheet roundtrip
csv = Exports::CsvExportService.call(original)
another_component = Component.new
Imports::SpreadsheetImportService.call(another_component, csv)

expect(another_component.rules.count).to eq(original.rules.count)
```

---

## Test Data

### Fixtures Available
- `spec/fixtures/xccdf/container_srg.xml` - 13 authored controls
- `spec/fixtures/xccdf/rhel9_v2r6_stig.xml` - Full DISA STIG
- `spec/fixtures/spreadsheets/container.xlsx` - Same as XCCDF
- Root: `Application_Core_SRG_Core.xml` - Core SRG
- Root: `Operating_System_Core_Core.xml` - OS SRG

### Test Components
- Container SRG: 13 primary, 251 satisfied, 264 total
- Application Core: 263 requirements
- OS Core: 263 requirements

---

## Continuous Testing During Development

### TDD Approach
1. Write failing test first
2. Implement minimal code to pass
3. Refactor for quality
4. Ensure test still passes
5. Commit

### Red-Green-Refactor Cycle
```bash
# Red: Write failing test
bundle exec rspec spec/services/imports/xccdf_import_service_spec.rb
# Should fail

# Green: Make it pass
# Implement XccdfImportService

bundle exec rspec spec/services/imports/xccdf_import_service_spec.rb
# Should pass

# Refactor: Clean up code
# Improve readability, remove duplication

bundle exec rspec spec/services/imports/xccdf_import_service_spec.rb
# Should still pass
```

---

## When Tests Fail

### Debugging Process
1. Read the failure message carefully
2. Check if it's a test issue or code issue
3. Fix the ROOT CAUSE (not the test)
4. Verify fix with test
5. Check for side effects

### Never Do This
- ❌ Comment out failing tests
- ❌ Skip failing tests with `xit` or `:skip`
- ❌ Weaken assertions to make tests pass
- ❌ Test around bugs instead of fixing them

### Always Do This
- ✅ Find and fix root cause
- ✅ Ensure tests are correct
- ✅ Ensure code is correct
- ✅ Add more tests if needed
- ✅ Fix completely before moving on

---

## Final Quality Check (Before Marking Phase Complete)

### Checklist
- [ ] All automated tests pass
- [ ] All manual tests pass
- [ ] Code coverage targets met
- [ ] RuboCop clean
- [ ] Brakeman clean
- [ ] No N+1 queries
- [ ] Performance same or better
- [ ] Documentation updated
- [ ] PROGRESS.md updated
- [ ] Changes committed
- [ ] Ready for next phase

### Sign-off
```
Phase [N] Complete ✅

Tests: [X] passing, 0 failures
Coverage: [Y]%
RuboCop: Clean
Brakeman: Clean
Performance: [Improvement/Maintained]

Ready for Phase [N+1]
```

---

**Quality is non-negotiable. Every phase must meet all criteria.**
