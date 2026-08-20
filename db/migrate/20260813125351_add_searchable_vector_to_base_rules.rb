# frozen_string_literal: true

# Stored full-text vector for the requirement search. The column is
# trigger-maintained (never a generated column) because it folds in content
# from associated tables — checks and disa_rule_descriptions — which a
# generated column cannot reference. Definitions live in db/functions and
# db/triggers (fx); the vector compute has ONE home:
# base_rule_searchable_vector.
class AddSearchableVectorToBaseRules < ActiveRecord::Migration[8.0]
  def change
    add_column :base_rules, :searchable, :tsvector

    create_function :base_rule_searchable_vector
    create_function :base_rules_searchable_trigger
    create_function :base_rule_children_searchable_trigger

    create_trigger :base_rules_searchable, on: :base_rules
    create_trigger :checks_searchable, on: :checks
    create_trigger :disa_rule_descriptions_searchable, on: :disa_rule_descriptions
  end
end
