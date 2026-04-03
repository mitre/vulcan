# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: VulcanAuditable provides project-standard audit defaults.
# All models should use `vulcan_audited` instead of raw `audited` to ensure
# consistent max_audits, timestamp exclusion, and future audit configuration.
RSpec.describe 'VulcanAuditable concern' do
  # Use a real model to test the concern's effect on audited configuration
  describe 'audit defaults applied to Rule' do
    it 'has max_audits set to 1000' do
      # The audited gem stores config in audited_options
      expect(Rule.audited_options[:max_audits]).to eq(1000)
    end

    it 'excludes created_at and updated_at from audit tracking' do
      except = Rule.audited_options[:except]
      expect(except).to include('created_at')
      expect(except).to include('updated_at')
    end

    it 'tracks locked_fields changes' do
      except = Rule.audited_options[:except]
      expect(except).not_to include('locked_fields')
      expect(except).not_to include('locked')
    end
  end

  describe 'audit defaults applied to Component' do
    it 'has max_audits set to 1000' do
      expect(Component.audited_options[:max_audits]).to eq(1000)
    end

    it 'excludes timestamps' do
      except = Component.audited_options[:except]
      expect(except).to include('created_at')
      expect(except).to include('updated_at')
    end
  end

  describe 'audit defaults applied to Project' do
    it 'has max_audits set to 1000' do
      expect(Project.audited_options[:max_audits]).to eq(1000)
    end

    it 'has associated audits enabled (can see component/membership changes)' do
      expect(Project.new.respond_to?(:own_and_associated_audits)).to be true
    end
  end

  describe 'consistent configuration across all audited models' do
    it 'all except-based models have max_audits 1000 and exclude timestamps' do
      %w[Rule Component Project Membership AdditionalQuestion].each do |model_name|
        klass = model_name.constantize
        expect(klass.audited_options[:max_audits]).to eq(1000), "#{model_name} max_audits"
        except = klass.audited_options[:except]
        expect(except).to include('created_at'), "#{model_name} missing created_at exclusion"
        expect(except).to include('updated_at'), "#{model_name} missing updated_at exclusion"
      end
    end

    it 'all only-based models have max_audits 1000 and exclude timestamps implicitly' do
      %w[User AdditionalAnswer].each do |model_name|
        klass = model_name.constantize
        expect(klass.audited_options[:max_audits]).to eq(1000), "#{model_name} max_audits"
        only = klass.audited_options[:only]
        expect(only).not_to be_empty, "#{model_name} only list empty"
        expect(only).not_to include('created_at'), "#{model_name} tracks created_at"
        expect(only).not_to include('updated_at'), "#{model_name} tracks updated_at"
      end
    end
  end
end
