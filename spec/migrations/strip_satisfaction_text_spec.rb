# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'StripSatisfactionTextFromVendorComments migration', type: :model do
  # REQUIREMENT: DB migration strips stale satisfaction text from vendor_comments
  # and vuln_discussion columns, leaving user-authored content intact.

  let_it_be(:shared_srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:shared_component) do
    project = Project.create!(name: 'Migration Test')
    Component.create!(project: project, name: 'Migration Test Component', title: 'Migration Test STIG',
                      version: 'Test V1R1', prefix: 'TSTT-01', based_on: shared_srg)
  end

  before do
    @srg = shared_srg
    @component = shared_component.reload
  end

  describe 'SATISFACTION_STRIP_PATTERN' do
    # These test the Ruby regex that the migration's SQL equivalent must match

    it 'strips "Satisfies: ..." from end of text, preserving user content' do
      input = 'User comment here. Satisfies: TST-01-000001, TST-01-000002.'
      result = input.sub(Rule::SATISFACTION_STRIP_PATTERN, '').strip
      expect(result).to eq('User comment here.')
    end

    it 'strips "Satisfied By: ..." from end of text' do
      input = 'Some notes. Satisfied By: TST-01-000001.'
      result = input.sub(Rule::SATISFACTION_STRIP_PATTERN, '').strip
      expect(result).to eq('Some notes.')
    end

    it 'strips when satisfaction text is the entire string' do
      input = 'Satisfies: SRG-OS-000480-GPOS-00227.'
      result = input.sub(Rule::SATISFACTION_STRIP_PATTERN, '').strip
      expect(result).to eq('')
    end

    it 'preserves text that does not contain satisfaction keywords' do
      input = 'Normal vendor comment with no satisfaction info.'
      result = input.sub(Rule::SATISFACTION_STRIP_PATTERN, '').strip
      expect(result).to eq(input)
    end

    it 'is case-insensitive' do
      input = 'Comment. SATISFIED BY: TST-01-000001.'
      result = input.sub(Rule::SATISFACTION_STRIP_PATTERN, '').strip
      expect(result).to eq('Comment.')
    end
  end

  describe 'migration scoping' do
    # REQUIREMENT: Migration ONLY touches component rules (type = 'Rule').
    # STIG/SRG reference data (SrgRule, StigRule) must NEVER be modified.

    it 'does NOT strip satisfaction text from SRG rule vuln_discussion' do
      srg_rule = @srg.srg_rules.first
      desc = srg_rule.disa_rule_descriptions.first || srg_rule.disa_rule_descriptions.create!
      original_text = 'SRG requirement text. Satisfies: SRG-OS-000480-GPOS-00227.'
      desc.update_column(:vuln_discussion, original_text)

      # Run the scoped SQL (same as migration)
      ActiveRecord::Base.connection.execute(<<-SQL.squish)
        UPDATE disa_rule_descriptions
        SET vuln_discussion = NULLIF(TRIM(regexp_replace(vuln_discussion, '\\s*\\m(Satisfi(ed\\s+By|es))\\s*:.*$', '', 'i')), '')
        WHERE base_rule_id IN (SELECT id FROM base_rules WHERE type = 'Rule')
          AND vuln_discussion ~* '(satisfies|satisfied\\s+by)\\s*:'
      SQL

      desc.reload
      expect(desc.vuln_discussion).to eq(original_text)
    end

    it 'DOES strip satisfaction text from component rule vuln_discussion' do
      component_rule = @component.rules.first
      desc = component_rule.disa_rule_descriptions.first
      desc.update_column(:vuln_discussion, 'Component vuln text. Satisfies: SRG-OS-000480-GPOS-00227.')

      ActiveRecord::Base.connection.execute(<<-SQL.squish)
        UPDATE disa_rule_descriptions
        SET vuln_discussion = NULLIF(TRIM(regexp_replace(vuln_discussion, '\\s*\\m(Satisfi(ed\\s+By|es))\\s*:.*$', '', 'i')), '')
        WHERE base_rule_id IN (SELECT id FROM base_rules WHERE type = 'Rule')
          AND vuln_discussion ~* '(satisfies|satisfied\\s+by)\\s*:'
      SQL

      desc.reload
      expect(desc.vuln_discussion).to eq('Component vuln text.')
    end
  end

  describe 'SQL strip via update_column' do
    # Simulate what the migration does using the same regex pattern on real DB records

    it 'strips satisfaction text from vendor_comments in the database' do
      rule = @component.rules.first
      rule.update_column(:vendor_comments, 'User text. Satisfies: TST-01-000001, TST-01-000002.')

      # Run the same SQL the migration uses
      ActiveRecord::Base.connection.execute(<<-SQL.squish)
        UPDATE base_rules
        SET vendor_comments = NULLIF(TRIM(regexp_replace(vendor_comments, '\\s*\\m(Satisfi(ed\\s+By|es))\\s*:.*$', '', 'i')), '')
        WHERE id = #{rule.id}
      SQL

      rule.reload
      expect(rule.vendor_comments).to eq('User text.')
    end

    it 'sets vendor_comments to NULL when satisfaction text is the entire value' do
      rule = @component.rules.first
      rule.update_column(:vendor_comments, 'Satisfies: TST-01-000001.')

      ActiveRecord::Base.connection.execute(<<-SQL.squish)
        UPDATE base_rules
        SET vendor_comments = NULLIF(TRIM(regexp_replace(vendor_comments, '\\s*\\m(Satisfi(ed\\s+By|es))\\s*:.*$', '', 'i')), '')
        WHERE id = #{rule.id}
      SQL

      rule.reload
      expect(rule.vendor_comments).to be_nil
    end

    it 'strips satisfaction text from vuln_discussion in the database' do
      rule = @component.rules.first
      desc = rule.disa_rule_descriptions.first
      desc.update_column(:vuln_discussion, 'Vulnerability details. Satisfies: SRG-OS-000480-GPOS-00227.')

      ActiveRecord::Base.connection.execute(<<-SQL.squish)
        UPDATE disa_rule_descriptions
        SET vuln_discussion = NULLIF(TRIM(regexp_replace(vuln_discussion, '\\s*\\m(Satisfi(ed\\s+By|es))\\s*:.*$', '', 'i')), '')
        WHERE id = #{desc.id}
      SQL

      desc.reload
      expect(desc.vuln_discussion).to eq('Vulnerability details.')
    end
  end
end
