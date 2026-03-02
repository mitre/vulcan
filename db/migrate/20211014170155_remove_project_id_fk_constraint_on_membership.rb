# frozen_string_literal: true

class RemoveProjectIdFkConstraintOnMembership < ActiveRecord::Migration[6.1]
  def change
    # This was a FK left behind from when ProjectMembers referenced only projects
    remove_foreign_key :memberships, column: :membership_id
  end
end
