# Gem Update Research for Rails 7 Compatibility

## Summary of Findings

### 1. audited (5.3.3 → 5.8.0)
**Recommendation: UPDATE to 5.8.0**
- **Rails 7 Support**: Added in version 5.0.2 ("Relax ActiveRecord version constraint to support Rails 7")
- **Rails 7.1 Support**: Added in version 5.4.0
- **Rails 7.2 Support**: Added in version 5.7.0
- **Rails 8 Support**: Added in version 5.7.0
- **Breaking Changes**: None for Rails 7 specifically
- **Benefits**: Better Rails 7.x compatibility, ongoing maintenance
- **Risk**: Low - mostly compatibility improvements

### 2. factory_bot_rails (5.2.0 → 6.4.4)
**Recommendation: UPDATE to 6.4.4**
- **Rails 7 Compatibility**: Supported since 6.x versions
- **Rails 7.1.2 Fix**: Version 6.4.2 fixed "Rails 7.1.2 + monkey-patched ActiveRecord compatibility"
- **Breaking Changes in 6.0.0**:
  - Removed support for Ruby 2.3, 2.4
  - Removed support for Rails 4.2
  - Removed 'factory_bot.register_reloader' initializer
- **Benefits**: Rails 7.1.2 compatibility fix, ongoing maintenance
- **Risk**: Medium - review usage of removed initializer if used

### 3. rspec-rails (4.0.2 → 6.0.0+)
**Recommendation: UPDATE to 6.0.x or 6.1.x (not 8.0.0)**
- **Rails 7 Support**: Added in version 6.0.0
- **Version Support Matrix**:
  - rspec-rails 4.x: Rails 5 and 6 only
  - rspec-rails 5.x: Rails 5.2+ (dropped older Rails)
  - rspec-rails 6.x: Rails 6.1+ with Rails 7 support
  - rspec-rails 7.x: Rails 7.0+ only
  - rspec-rails 8.x: Rails 7+ only
- **Breaking Changes**:
  - 5.0.0: Dropped Rails < 5.2
  - 6.0.0: Dropped Rails < 6.1, Ruby < 2.5
- **Benefits**: Proper Rails 7 support, new matchers
- **Risk**: Medium - need to ensure Rails 6.1 compatibility
- **Note**: Version 8.0.0 is too aggressive for current Rails 6.1.4.6

### 4. selenium-webdriver (4.26.0 → 4.33.0)
**Recommendation: UPDATE to 4.33.0**
- **No Rails-specific compatibility issues**
- **Notable Changes**:
  - 4.27.0: Updated minimum Ruby to 3.1, fixed `uri` gem deprecation warning
  - 4.30.0: Removed deprecated HTML5 web storage features
  - 4.33.0: Upgraded to Ruby 3.2
- **Breaking Changes**: 
  - Minimum Ruby version increased (but we're on 2.7.5)
  - Removed deprecated features
- **Benefits**: Bug fixes, Chrome driver updates, deprecation fixes
- **Risk**: High - requires Ruby 3.1+ (we're on 2.7.5)
- **Alternative**: Stay on 4.26.0 or update to 4.26.x patch versions only

### 5. wisper (2.0.1 → 3.0.0)
**Recommendation: UPDATE to 3.0.0**
- **No Rails-specific compatibility issues**
- **Breaking Changes**: 
  - Removes support for Ruby 2.6 and lower (we're on 2.7.5, so OK)
- **New Features**:
  - Ruby 3.0 keyword arguments support
  - Documentation improvements
- **Benefits**: Ruby 3.x compatibility for future
- **Risk**: Low - minimal breaking changes

## Recommended Update Strategy

### Phase 1 - Safe Updates (Low Risk)
1. **audited**: 5.3.3 → 5.8.0
2. **wisper**: 2.0.1 → 3.0.0

### Phase 2 - Medium Risk Updates
3. **factory_bot_rails**: 5.2.0 → 6.4.4
4. **rspec-rails**: 4.0.2 → 6.0.4 or 6.1.0 (latest 6.x)

### Phase 3 - Hold or Patch Only
5. **selenium-webdriver**: Keep at 4.26.0 until Ruby upgrade
   - Alternative: Check for 4.26.x patch versions

## Testing Plan
After each update:
1. Run full test suite: `bundle exec rspec`
2. Check for deprecation warnings
3. Verify CI/CD passes
4. Test development environment thoroughly

## Notes
- Most gems have good Rails 7 support in their newer versions
- selenium-webdriver requires Ruby 3.1+ in newer versions, so it's blocked by Ruby version
- rspec-rails 8.0.0 might be too aggressive for Rails 6.1.4.6
- All other gems should be safe to update with proper testing