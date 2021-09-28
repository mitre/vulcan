# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review, type: :model do
  before :each do
    srg_xml = file_fixture("U_Web_Server_V2R3_Manual-xccdf.xml").read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    # Create projects
    @p1 = Project.create(name: 'P1', prefix: 'AAAA-00', based_on: srg)
    @p2 = Project.create(name: 'P2', prefix: 'BBBB-00', based_on: srg)

    # Create Users
    @p_admin = build(:user)
    @p_reviewer = build(:user)
    @p_author = build(:user)
    @other_p_admin = build(:user)

    # Give users project roles
    ProjectMember.create!(user: @p_admin, project: @p1, role: 'admin')
    ProjectMember.create!(user: @p_reviewer, project: @p1, role: 'reviewer')
    ProjectMember.create!(user: @p_author, project: @p1, role: 'author')
    ProjectMember.create!(user: @other_p_admin, project: @p2, role: 'admin')

    # Create rules
    @p1r1 = Rule.create!(
      project: @p1,
      rule_id: 'P1-R1',
      status: 'Applicable - Configurable',
      rule_severity: 'medium'
    )
  end

  context 'custom validations' do
    it 'properly validates cannot_be_locked_and_under_review' do
      expect(@p1r1.valid?).to eq(true)

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.locked = false
      expect(@p1r1.save).to eq(true)

      @p1r1.review_requestor_id = nil
      @p1r1.locked = true
      expect(@p1r1.save).to eq(true)

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.locked = true
      expect(@p1r1.save).to eq(false)
      expect(@p1r1.errors[:base]).to include('Control cannot be under review and locked at the same time.')
    end

    it 'properly validates prevent_destroy_if_under_review_or_locked when under review' do
      @p1r1.update(review_requestor_id: @p_admin.id)
      @p1r1.reload
      @p1r1.destroy
      expect(@p1r1.errors[:base]).to include('Control is under review and cannot be destroyed')
    end

    it 'properly validates prevent_destroy_if_under_review_or_locked when under locked' do
      @p1r1.update(locked: true)
      @p1r1.reload
      @p1r1.destroy
      expect(@p1r1.errors[:base]).to include('Control is locked and cannot be destroyed')
      expect(Rule.find_by(id: @p1r1.id)).to_not eq(nil)
    end

    it 'properly validates review_fields_cannot_change_with_other_fields' do
      @p1r1.review_requestor_id = @p_admin.id
      expect(@p1r1.valid?).to eq(true)
      @p1r1.reload

      @p1r1.locked = true
      expect(@p1r1.valid?).to eq(true)
      @p1r1.reload

      @p1r1.status_justification = '...'
      expect(@p1r1.valid?).to eq(true)
      @p1r1.reload

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.status_justification = '...'
      expect(@p1r1.valid?).to eq(false)
      expect(@p1r1.errors[:base]).to include(
        'Cannot update review-related attributes with other non-review-related attributes'
      )
      @p1r1.reload
    end
  end
end
