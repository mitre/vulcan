# frozen_string_literal: true

require_relative 'seed_helpers'

class SeedContext # rubocop:disable Style/Documentation
  attr_reader :users, :projects, :components

  SYMBOL_TO_EMAIL = {
    admin: 'admin@example.com',
    viewer: 'viewer@example.com',
    author: 'author@example.com',
    reviewer: 'reviewer@example.com',
    container_sme: 'container-sme@example.org',
    platform_eng: 'platform-eng@example.org',
    compliance_analyst: 'compliance-analyst@example.org',
    stig_author: 'stig-author@example.org',
    devsecops: 'devsecops@example.org',
    infra_eng: 'infra-eng@example.org',
    qa_reviewer: 'qa-reviewer@example.org',
    security_reviewer: 'security-reviewer@example.org'
  }.freeze

  def initialize
    @users = User.all.index_by(&:email)
    @projects = Project.all.index_by(&:name)
    @components = Component.all.index_by(&:name)
    @admin = User.find_by(admin: true)
  end

  def user(key)
    case key
    when Symbol
      email = SYMBOL_TO_EMAIL[key]
      email ? (@users[email] || @admin) : @admin
    when String
      @users[key] || @admin
    end
  end

  def project(name)
    @projects[name]
  end

  def component(name)
    @components[name]
  end

  def rules_for(comp, limit: 6)
    rules_list = comp.rules.order(:rule_id).limit(limit).to_a
    rules_list.each_with_index.to_h { |rule, i| [:"rule_#{('a'.ord + i).chr}", rule] }
  end
end
