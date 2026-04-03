# frozen_string_literal: true

class AddInspecCodeLangToRules < ActiveRecord::Migration[6.1]
  def change
    add_column :base_rules, :inspec_control_body_lang, :text, default: 'ruby'
    add_column :base_rules, :inspec_control_file_lang, :text, default: 'ruby'
  end
end
