# RuboCop Technical Debt Tracking

## Context
During the Ruby 2.7.5 → 3.1.6 upgrade (January 2025), RuboCop was also upgraded from 1.25.1 to 1.79.2. This 50+ version jump introduced many new cops that flagged pre-existing issues in the codebase. These issues were temporarily excluded in `.rubocop.yml` to keep the upgrade PR focused.

## Technical Debt Items to Fix

### 1. Rails/I18nLocaleTexts (8 occurrences)
**Issue**: Hardcoded user-facing strings that should be in locale files
**Priority**: Medium
**Estimated Effort**: 2-3 hours

Files to fix:
- `app/controllers/stigs_controller.rb:59` - Flash alert message
- `app/models/additional_answer.rb:13` - Validation message
- `app/models/component_metadata.rb:6` - Validation message
- `app/models/membership.rb:30` - Validation message
- `app/models/project_access_request.rb:7` - Validation message
- `app/models/project_metadata.rb:6` - Validation message
- `app/models/security_requirements_guide.rb:14` - Validation message
- `app/models/stig.rb:10` - Validation message

**Fix Strategy**: 
- Move all strings to `config/locales/en.yml`
- Use proper I18n keys following Rails conventions
- Test that all messages still display correctly

### 2. Naming/PredicateMethod (4 occurrences)
**Issue**: Methods that should end with `?` based on their boolean nature
**Priority**: Low (requires API changes)
**Estimated Effort**: 1-2 hours + testing

Files to fix:
- `app/lib/xccdf/ident.rb:16` - Method `is_cci`
- `app/models/component.rb:228` - Method `has_validation_errors`
- `app/models/concerns/prefix_validator.rb:15` - Method `has_prefix`
- `app/controllers/concerns/oidc_discovery_helper.rb:209` - Method `validate_discovery_document`

**Fix Strategy**:
- Rename methods to end with `?` (e.g., `is_cci?`, `has_validation_errors?`)
- Update all callers throughout the codebase
- Consider adding deprecation warnings if these are public APIs

**Note**: The `validate_discovery_document` method is a special case - it doesn't return a boolean but raises errors, so the name might be correct as-is.

### 3. Style/SafeNavigationChainLength (5 occurrences)
**Issue**: Safe navigation chains longer than 2 calls (e.g., `foo&.bar&.baz&.qux`)
**Priority**: Medium (code clarity)
**Estimated Effort**: 1-2 hours

Files to fix:
- `app/models/base_rule.rb:52` - Long chain in rule processing
- `app/models/check.rb:14,15` - Two long chains in check validation
- `app/models/component.rb:405` - Long chain in component logic
- `lib/tasks/stig_and_srg_puller.rake:113` - Long chain in rake task

**Fix Strategy**:
- Refactor to use intermediate variables
- Consider using early returns with proper nil checking
- Add guard clauses where appropriate

### 4. Style/Documentation (9 occurrences)
**Issue**: Missing top-level documentation comments for classes
**Priority**: Low (documentation)
**Estimated Effort**: 1 hour

Files to fix:
- `app/lib/xccdf/idref/overrideable_idref.rb` - Missing class documentation
- `app/lib/xccdf/item/selectable_item.rb` - Missing class documentation
- `app/lib/xccdf/item/selectable_item/group.rb` - Missing class documentation
- `app/lib/xccdf/item/selectable_item/rule.rb` - Missing class documentation
- `app/lib/xccdf/item/value.rb` - Missing class documentation
- `app/lib/xccdf/warning.rb` - Missing class documentation
- `app/models/component_metadata.rb` - Missing class documentation
- `app/models/project_access_request.rb` - Missing class documentation
- `app/models/project_metadata.rb` - Missing class documentation

**Fix Strategy**:
- Add meaningful class-level documentation
- Describe the purpose and responsibility of each class
- Include usage examples where helpful

### 5. RSpec/IndexedLet (6 occurrences)
**Issue**: Let statements using numbers in their names (e.g., `let(:user2)`)
**Priority**: Low (test readability)
**Estimated Effort**: 30 minutes

Files to fix:
- `spec/controllers/registrations_controller_spec.rb:120,121,152,153` - Four indexed lets
- `spec/models/project_access_request_spec.rb:7,8` - Two indexed lets

**Fix Strategy**:
- Rename to meaningful names (e.g., `admin_user`, `regular_user`, `guest_user`)
- Update all references in the specs

### 6. Metrics/CollectionLiteralLength (1 occurrence)
**Issue**: Large array/hash literal hardcoded in the code
**Priority**: Medium (maintainability)
**Estimated Effort**: 1-2 hours

Files to fix:
- `app/lib/cci_map/constants.rb:6` - Large collection literal

**Fix Strategy**:
- Move data to a YAML or JSON file
- Load the data from the external file
- Consider if this should be in the database instead

## Tracking Progress

- [ ] Create issue for Rails/I18nLocaleTexts fixes
- [ ] Create issue for Naming/PredicateMethod fixes
- [ ] Create issue for Style/SafeNavigationChainLength fixes
- [ ] Create issue for Style/Documentation fixes
- [ ] Create issue for RSpec/IndexedLet fixes
- [ ] Create issue for Metrics/CollectionLiteralLength fix

## Notes

- These issues existed in the master branch before the Ruby 3.1 upgrade
- They were revealed by the RuboCop version upgrade (1.25.1 → 1.79.2)
- Fixing these will improve code quality and maintainability
- Consider grouping related fixes in single PRs where it makes sense