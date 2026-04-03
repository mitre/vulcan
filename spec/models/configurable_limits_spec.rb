# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Input length limits must be configurable via Settings so that
# Vulcan administrators can tune limits per deployment via environment variables.
# Models must read from Settings.input_limits, NOT use hardcoded numbers.
#
# Default limits (based on real DISA STIG/SRG data analysis across 1,785 rules):
#   short_string: 255   (real max: 25 — IDs, version strings)
#   ident: 2048         (real max: 310 — comma-joined CCI list)
#   title: 500          (real max: 436 — rule titles)
#   medium_text: 1000   (status justification, brief text)
#   long_text: 10000    (real max: 6330 — vuln_discussion, check_content, fixtext)
#   inspec_code: 50000  (user-authored InSpec control bodies)
#   component_name: 255
#   component_prefix: 10
#   component_title: 500
#   component_description: 5000
#   project_name: 255
#   project_description: 5000
RSpec.describe 'Configurable input length limits' do
  describe 'Settings.input_limits' do
    it 'provides default values for rule field limits' do
      limits = Settings.input_limits

      expect(limits.short_string).to eq(255)
      expect(limits.ident).to eq(2048)
      expect(limits.title).to eq(500)
      expect(limits.medium_text).to eq(1000)
      expect(limits.long_text).to eq(10_000)
      expect(limits.inspec_code).to eq(50_000)
    end

    it 'provides default values for entity and benchmark limits' do
      limits = Settings.input_limits

      expect(limits.component_name).to eq(255)
      expect(limits.component_prefix).to eq(10)
      expect(limits.component_title).to eq(500)
      expect(limits.component_description).to eq(5000)
      expect(limits.project_name).to eq(255)
      expect(limits.project_description).to eq(5000)
      expect(limits.user_name).to eq(255)
      expect(limits.user_email).to eq(255)
      expect(limits.review_comment).to eq(10_000)
      expect(limits.benchmark_name).to eq(500)
      expect(limits.benchmark_title).to eq(500)
      expect(limits.benchmark_description).to eq(10_000)
    end
  end

  describe 'BaseRule reads limits from Settings' do
    it 'uses Settings.input_limits.short_string for ID fields' do
      rule = BaseRule.new
      rule.rule_id = 'x' * (Settings.input_limits.short_string + 1)
      rule.valid?
      expect(rule.errors[:rule_id]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.ident for ident field' do
      rule = BaseRule.new
      rule.ident = 'x' * (Settings.input_limits.ident + 1)
      rule.valid?
      expect(rule.errors[:ident]).to include(
        "is too long (maximum is #{Settings.input_limits.ident} characters)"
      )
    end

    it 'uses Settings.input_limits.title for title field' do
      rule = BaseRule.new
      rule.title = 'x' * (Settings.input_limits.title + 1)
      rule.valid?
      expect(rule.errors[:title]).to include(
        "is too long (maximum is #{Settings.input_limits.title} characters)"
      )
    end

    it 'uses Settings.input_limits.long_text for fixtext field' do
      rule = BaseRule.new
      rule.fixtext = 'x' * (Settings.input_limits.long_text + 1)
      rule.valid?
      expect(rule.errors[:fixtext]).to include(
        "is too long (maximum is #{Settings.input_limits.long_text} characters)"
      )
    end

    it 'uses Settings.input_limits.medium_text for status_justification' do
      rule = BaseRule.new
      rule.status_justification = 'x' * (Settings.input_limits.medium_text + 1)
      rule.valid?
      expect(rule.errors[:status_justification]).to include(
        "is too long (maximum is #{Settings.input_limits.medium_text} characters)"
      )
    end

    it 'uses Settings.input_limits.inspec_code for inspec_control_body' do
      rule = BaseRule.new
      rule.inspec_control_body = 'x' * (Settings.input_limits.inspec_code + 1)
      rule.valid?
      expect(rule.errors[:inspec_control_body]).to include(
        "is too long (maximum is #{Settings.input_limits.inspec_code} characters)"
      )
    end
  end

  describe 'DisaRuleDescription reads limits from Settings' do
    it 'uses Settings.input_limits.long_text for vuln_discussion' do
      desc = DisaRuleDescription.new
      desc.vuln_discussion = 'x' * (Settings.input_limits.long_text + 1)
      desc.valid?
      expect(desc.errors[:vuln_discussion]).to include(
        "is too long (maximum is #{Settings.input_limits.long_text} characters)"
      )
    end
  end

  describe 'Check reads limits from Settings' do
    it 'uses Settings.input_limits.short_string for system field' do
      check = Check.new
      check.system = 'x' * (Settings.input_limits.short_string + 1)
      check.valid?
      expect(check.errors[:system]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.long_text for content field' do
      check = Check.new
      check.content = 'x' * (Settings.input_limits.long_text + 1)
      check.valid?
      expect(check.errors[:content]).to include(
        "is too long (maximum is #{Settings.input_limits.long_text} characters)"
      )
    end
  end

  describe 'Component reads limits from Settings' do
    it 'uses Settings.input_limits.component_name for name' do
      component = Component.new
      component.name = 'x' * (Settings.input_limits.component_name + 1)
      component.valid?
      expect(component.errors[:name]).to include(
        "is too long (maximum is #{Settings.input_limits.component_name} characters)"
      )
    end

    it 'uses Settings.input_limits.component_title for title' do
      component = Component.new
      component.title = 'x' * (Settings.input_limits.component_title + 1)
      component.valid?
      expect(component.errors[:title]).to include(
        "is too long (maximum is #{Settings.input_limits.component_title} characters)"
      )
    end

    it 'uses Settings.input_limits.component_description for description' do
      component = Component.new
      component.description = 'x' * (Settings.input_limits.component_description + 1)
      component.valid?
      expect(component.errors[:description]).to include(
        "is too long (maximum is #{Settings.input_limits.component_description} characters)"
      )
    end
  end

  describe 'Project reads limits from Settings' do
    it 'uses Settings.input_limits.project_name for name' do
      project = Project.new
      project.name = 'x' * (Settings.input_limits.project_name + 1)
      project.valid?
      expect(project.errors[:name]).to include(
        "is too long (maximum is #{Settings.input_limits.project_name} characters)"
      )
    end

    it 'uses Settings.input_limits.project_description for description' do
      project = Project.new
      project.description = 'x' * (Settings.input_limits.project_description + 1)
      project.valid?
      expect(project.errors[:description]).to include(
        "is too long (maximum is #{Settings.input_limits.project_description} characters)"
      )
    end
  end

  describe 'BaseRule covers language fields' do
    it 'uses Settings.input_limits.short_string for inspec_control_body_lang' do
      rule = BaseRule.new
      rule.inspec_control_body_lang = 'x' * (Settings.input_limits.short_string + 1)
      rule.valid?
      expect(rule.errors[:inspec_control_body_lang]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.short_string for inspec_control_file_lang' do
      rule = BaseRule.new
      rule.inspec_control_file_lang = 'x' * (Settings.input_limits.short_string + 1)
      rule.valid?
      expect(rule.errors[:inspec_control_file_lang]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end
  end

  describe 'User reads limits from Settings' do
    it 'uses Settings.input_limits.user_name for name' do
      user = User.new
      user.name = 'x' * (Settings.input_limits.user_name + 1)
      user.valid?
      expect(user.errors[:name]).to include(
        "is too long (maximum is #{Settings.input_limits.user_name} characters)"
      )
    end

    it 'uses Settings.input_limits.user_email for email' do
      user = User.new
      user.email = "#{'x' * Settings.input_limits.user_email}@example.com"
      user.valid?
      expect(user.errors[:email]).to include(
        "is too long (maximum is #{Settings.input_limits.user_email} characters)"
      )
    end
  end

  describe 'Review reads limits from Settings' do
    it 'uses Settings.input_limits.short_string for action' do
      review = Review.new
      review.action = 'x' * (Settings.input_limits.short_string + 1)
      review.valid?
      expect(review.errors[:action]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.review_comment for comment' do
      review = Review.new
      review.comment = 'x' * (Settings.input_limits.review_comment + 1)
      review.valid?
      expect(review.errors[:comment]).to include(
        "is too long (maximum is #{Settings.input_limits.review_comment} characters)"
      )
    end
  end

  describe 'SecurityRequirementsGuide reads limits from Settings' do
    it 'uses Settings.input_limits.short_string for srg_id' do
      srg = SecurityRequirementsGuide.new
      srg.srg_id = 'x' * (Settings.input_limits.short_string + 1)
      srg.valid?
      expect(srg.errors[:srg_id]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.benchmark_title for title' do
      srg = SecurityRequirementsGuide.new
      srg.title = 'x' * (Settings.input_limits.benchmark_title + 1)
      srg.valid?
      expect(srg.errors[:title]).to include(
        "is too long (maximum is #{Settings.input_limits.benchmark_title} characters)"
      )
    end

    it 'uses Settings.input_limits.short_string for version' do
      srg = SecurityRequirementsGuide.new
      srg.version = 'x' * (Settings.input_limits.short_string + 1)
      srg.valid?
      expect(srg.errors[:version]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.benchmark_name for name' do
      srg = SecurityRequirementsGuide.new
      srg.name = 'x' * (Settings.input_limits.benchmark_name + 1)
      srg.valid?
      expect(srg.errors[:name]).to include(
        "is too long (maximum is #{Settings.input_limits.benchmark_name} characters)"
      )
    end
  end

  describe 'Stig reads limits from Settings' do
    it 'uses Settings.input_limits.short_string for stig_id' do
      stig = Stig.new
      stig.stig_id = 'x' * (Settings.input_limits.short_string + 1)
      stig.valid?
      expect(stig.errors[:stig_id]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.benchmark_title for title' do
      stig = Stig.new
      stig.title = 'x' * (Settings.input_limits.benchmark_title + 1)
      stig.valid?
      expect(stig.errors[:title]).to include(
        "is too long (maximum is #{Settings.input_limits.benchmark_title} characters)"
      )
    end

    it 'uses Settings.input_limits.benchmark_description for description' do
      stig = Stig.new
      stig.description = 'x' * (Settings.input_limits.benchmark_description + 1)
      stig.valid?
      expect(stig.errors[:description]).to include(
        "is too long (maximum is #{Settings.input_limits.benchmark_description} characters)"
      )
    end

    it 'uses Settings.input_limits.short_string for version' do
      stig = Stig.new
      stig.version = 'x' * (Settings.input_limits.short_string + 1)
      stig.valid?
      expect(stig.errors[:version]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.benchmark_name for name' do
      stig = Stig.new
      stig.name = 'x' * (Settings.input_limits.benchmark_name + 1)
      stig.valid?
      expect(stig.errors[:name]).to include(
        "is too long (maximum is #{Settings.input_limits.benchmark_name} characters)"
      )
    end
  end

  describe 'Component covers admin fields' do
    it 'uses Settings.input_limits.short_string for admin_name' do
      component = Component.new
      component.admin_name = 'x' * (Settings.input_limits.short_string + 1)
      component.valid?
      expect(component.errors[:admin_name]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.short_string for admin_email' do
      component = Component.new
      component.admin_email = 'x' * (Settings.input_limits.short_string + 1)
      component.valid?
      expect(component.errors[:admin_email]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end
  end

  describe 'Project covers admin fields' do
    it 'uses Settings.input_limits.short_string for admin_name' do
      project = Project.new
      project.admin_name = 'x' * (Settings.input_limits.short_string + 1)
      project.valid?
      expect(project.errors[:admin_name]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end

    it 'uses Settings.input_limits.short_string for admin_email' do
      project = Project.new
      project.admin_email = 'x' * (Settings.input_limits.short_string + 1)
      project.valid?
      expect(project.errors[:admin_email]).to include(
        "is too long (maximum is #{Settings.input_limits.short_string} characters)"
      )
    end
  end
end
