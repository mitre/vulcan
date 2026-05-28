# Fixes Required & Test Coverage Plan

**Created:** 2025-11-26
**Purpose:** Ensure all fixes have proper test coverage to prevent regression

---

## ✅ COMPLETED - With Tests

### 1. Nested Attributes Save Bug ✅
**Status:** Fixed in 06a1d10
**Tests:** ✅ 6 request specs (spec/requests/rules_spec.rb)
- Tests check content updates
- Tests fixtext updates
- Tests disa_rule_description updates
- Tests multi-field updates
**Coverage:** Complete

### 2. Spreadsheet Parser Period Bug ✅
**Status:** Fixed in 985c5fd
**Tests:** ✅ 3 parser tests + 3 status tests (spec/models/components_spec.rb)
- Tests with trailing period
- Tests without trailing period
- Tests with extra whitespace
**Coverage:** Complete

### 3. Vue Reactivity Bugs ✅
**Status:** Fixed in f458850
**Tests:** ✅ 21 Vitest tests (4 component spec files)
- BasicRuleForm: 7 tests
- AdvancedRuleForm: 6 tests
- CheckForm: 4 tests
- RuleForm: 4 tests
**Coverage:** Complete

### 4. User Privacy Issue ✅
**Status:** Fixed in 1763e26
**Tests:** ✅ 3 security tests (spec/models/project_spec.rb)
- Tests available_members returns empty
- Tests no email leakage
- Tests count is zero
**Coverage:** Complete

### 5. Security Hardening ✅
**Status:** Fixed in 7f6c753
**Tests:** ⚠️ NEEDS INTEGRATION TESTS
- File upload validation (needs test)
- Security headers (needs test)
- Rate limiting (needs test)

---

## 🔧 NEEDS TESTS - High Priority

### 6. File Upload Validation
**Code:** ✅ Implemented (Component.validate_spreadsheet_file)
**Tests:** ❌ MISSING

**Required Tests:**
```ruby
# spec/models/component_spec.rb
context 'spreadsheet file validation' do
  it 'rejects non-spreadsheet files' do
    # Upload .exe, .zip, .txt
    # Verify error added
  end

  it 'accepts valid spreadsheet extensions' do
    # Upload .xlsx, .xls, .csv, .ods
    # Verify no errors
  end

  it 'rejects files over 100MB' do
    # Mock large file
    # Verify size error
  end
end
```

**Estimated Time:** 30 minutes

### 7. Rate Limiting
**Code:** ✅ Implemented (rack_attack.rb)
**Tests:** ❌ MISSING

**Required Tests:**
```ruby
# spec/requests/rate_limiting_spec.rb (NEW FILE)
RSpec.describe 'Rate Limiting', type: :request do
  describe 'login throttling' do
    it 'allows 5 login attempts then blocks' do
      # Make 5 login requests
      # 6th should return 429
    end

    it 'resets after 20 seconds' do
      # Test time-based reset
    end
  end

  describe 'registration throttling' do
    it 'allows 3 registrations per IP per hour'
  end

  describe 'API throttling' do
    it 'allows 300 requests per 5 minutes'
  end

  describe 'safelists' do
    it 'allows unlimited localhost requests'
    it 'allows unlimited health check requests'
  end
end
```

**Estimated Time:** 1 hour

### 8. Security Headers
**Code:** ✅ Implemented (security_headers.rb)
**Tests:** ❌ MISSING

**Required Tests:**
```ruby
# spec/requests/security_headers_spec.rb (NEW FILE)
RSpec.describe 'Security Headers', type: :request do
  it 'includes X-Frame-Options header' do
    get '/'
    expect(response.headers['X-Frame-Options']).to eq('SAMEORIGIN')
  end

  it 'includes X-Content-Type-Options header' do
    get '/'
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
  end

  it 'includes X-XSS-Protection header' do
    get '/'
    expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
  end

  it 'includes Referrer-Policy header' do
    get '/'
    expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
  end
end
```

**Estimated Time:** 20 minutes

---

## 🔍 NEEDS INVESTIGATION

### 9. Member Addition UI Broken
**Issue:** available_members now returns [] (security fix side effect)
**Impact:** Cannot add members via autocomplete
**Status:** ⚠️ BROKEN FEATURE

**Needs:**
1. **Decision:** How should member addition work?
   - Option A: Admin-only user search endpoint
   - Option B: Direct email invitation
   - Option C: Organization-scoped autocomplete

2. **Implementation:** Based on chosen approach

3. **Tests:**
   - Request spec for member addition
   - Authorization tests
   - Privacy tests (no email leakage)

**Estimated Time:** 2-3 hours

---

## 📋 RECOMMENDED ADDITIONS

### 10. Add Security Event Logging
**Purpose:** Track failed logins, unauthorized access attempts
**Priority:** Medium

**Implementation:**
```ruby
# app/models/security_event.rb
class SecurityEvent < ApplicationRecord
  # track: event_type, user_id, ip_address, details, created_at
end

# In controllers:
SecurityEvent.create(
  event_type: 'failed_login',
  user_id: user&.id,
  ip_address: request.remote_ip,
  details: { email: params[:email] }
)
```

**Tests Needed:**
- Creates event on failed login
- Creates event on unauthorized access
- Limits event retention (30 days)

**Estimated Time:** 1-2 hours

### 11. Add Request Specs for Security Features
**Purpose:** Integration testing for security
**Priority:** High

**Needed:**
- Rate limiting integration tests
- Security headers in real responses
- File upload rejection tests
- Authorization boundary tests

**Estimated Time:** 2-3 hours

### 12. Add Database Constraints
**Purpose:** Data integrity at DB level
**Priority:** Medium

**Missing Constraints:**
- NOT NULL on critical fields
- CHECK constraints for enums
- Foreign key constraints (some might be missing)

**Estimated Time:** 1-2 hours

---

## 🎯 PRIORITY TASK LIST

### Immediate (Before Push):

**1. Add File Upload Validation Tests** (30 min)
- [ ] Test rejects invalid extensions
- [ ] Test accepts valid extensions
- [ ] Test file size limit
- [ ] Integration test with controller

**2. Add Security Headers Tests** (20 min)
- [ ] Test all headers present
- [ ] Test header values correct
- [ ] Test in all environments

**3. Add Rate Limiting Tests** (1 hour)
- [ ] Test login throttling
- [ ] Test registration throttling
- [ ] Test API throttling
- [ ] Test safelists work

**4. Fix Member Addition UI** (2-3 hours)
- [ ] Decide on approach
- [ ] Implement new member addition
- [ ] Add authorization tests
- [ ] Add privacy tests
- [ ] Manual testing

**Total Time:** 4-5 hours

### Soon (v2.3.1):

**5. Add Security Event Logging** (1-2 hours)
- [ ] Migration for security_events table
- [ ] Model with validations
- [ ] Controller integration
- [ ] Cleanup job (30 day retention)
- [ ] Tests for event creation

**6. Database Integrity Improvements** (1-2 hours)
- [ ] Audit NOT NULL constraints
- [ ] Add CHECK constraints for enums
- [ ] Verify foreign key constraints
- [ ] Migration to add missing constraints
- [ ] Tests for constraint violations

**7. Comprehensive Request Specs** (2-3 hours)
- [ ] Security features integration tests
- [ ] Authorization boundary tests
- [ ] Edge case testing

**Total Time:** 5-7 hours

---

## 📊 Current Test Coverage

**Backend:** 287 tests
- Models: Well covered
- Controllers: Good coverage (request specs)
- Security: 3 tests (needs more)
- Integration: Some (needs more)

**Frontend:** 28 tests
- Component logic: Good
- Integration: None (would need Playwright)

**Missing Coverage:**
- Security features integration
- File upload validation
- Rate limiting
- Security headers
- Member addition workflow

---

## 🚨 BREAKING CHANGES TO ADDRESS

### Member Addition UI
**What Broke:** available_members returns []
**Why:** Security fix to prevent email enumeration
**Impact:** Users can't add members via autocomplete

**Fix Options:**

**Option A: Admin Search Endpoint** (Recommended)
```ruby
# app/controllers/users_controller.rb
def search
  authorize_admin # Only admins

  query = params[:q]
  return head :bad_request if query.blank? || query.length < 3

  users = User.where("name ILIKE ? OR email ILIKE ?", "%#{query}%", "%#{query}%")
              .limit(20)
              .select(:id, :name, :email)

  render json: users
end
```

**Tests:**
- Only accessible by admins
- Requires 3+ characters
- Returns max 20 results
- No email in response unless needed

**Option B: Email Invitation**
```ruby
# Send email with invitation link
# User clicks link to join project
# No autocomplete needed
```

**Tests:**
- Sends invitation email
- Validates email format
- Prevents duplicate invitations
- Expires after 7 days

**Option C: Organization Scoping**
```ruby
# Only show users from same organization
def available_members
  # Get current user's domain
  user_domain = current_user.email.split('@').last

  # Find users with same domain who aren't members
  User.where("email LIKE ?", "%@#{user_domain}")
      .where.not(id: users.pluck(:id))
      .select(:id, :name, :email)
end
```

**Tests:**
- Only shows same-domain users
- Doesn't leak other orgs
- Works with multi-domain orgs

---

## 📝 TEST CHECKLIST

### Must Have Before Push:
- [ ] File upload validation tests (30 min)
- [ ] Security headers tests (20 min)
- [ ] Rate limiting tests (1 hour)
- [ ] Member addition fix + tests (2-3 hours)

### Should Have for v2.3.1:
- [ ] Security event logging tests
- [ ] Database constraint tests
- [ ] Integration tests for all security features
- [ ] Authorization boundary tests

### Nice to Have:
- [ ] Performance benchmarks
- [ ] Load testing
- [ ] Penetration testing
- [ ] Code coverage reports

---

## 🎯 RECOMMENDED APPROACH

**Today (4-5 hours):**
1. Add file upload tests
2. Add security headers tests
3. Add rate limiting tests
4. Decide on member addition approach
5. Implement & test member addition

**This ensures:**
- No regressions on security fixes
- Member addition works again
- All features tested
- Safe to push to production

**Tomorrow:**
- Security event logging
- Database constraints
- Markdown editor implementation

---

## 📦 WHAT'S READY TO PUSH NOW

**If you skip member addition fix:**
- 9 commits with full test coverage
- Just document member addition as "admin-only for now"
- Push and fix member addition in v2.3.1

**If you fix member addition:**
- 10 commits, fully tested
- All features working
- Production ready

**Your call!**

---

**Status:** Tests needed for security features, member addition broken
**Decision Needed:** Fix member addition now or later?
**Estimated Time:** 4-5 hours for complete test coverage + fix
