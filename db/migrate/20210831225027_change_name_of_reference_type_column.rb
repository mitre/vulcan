# frozen_string_literal: true

class ChangeNameOfReferenceTypeColumn < ActiveRecord::Migration[6.1]
  def change
    rename_column :references, :type, :reference_type
  end
end
