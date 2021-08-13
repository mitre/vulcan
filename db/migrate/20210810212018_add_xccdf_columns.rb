class AddXccdfColumns < ActiveRecord::Migration[6.1]
  def change
    add_column :rules, :status, :string
    add_column :rules, :status_justification, :text
    add_column :rules, :artifact_description, :text
    add_column :rules, :vendor_comments, :text
    add_column :rules, :rule_id, :string, null: false
    add_column :rules, :rule_severity, :string
    add_column :rules, :rule_weight, :string
    add_column :rules, :version, :string
    add_column :rules, :title, :string
    add_column :rules, :ident, :string
    add_column :rules, :ident_system, :string, default: 'http://iase.disa.mil/cci'
    add_column :rules, :fixtext, :text
    add_column :rules, :fixtext_fixref, :string
    add_column :rules, :fix_id, :string
    remove_column :rules, :description, :string

    create_table :checks do |t|
      t.references :rule
      t.string :system
      t.string :content_ref_name
      t.string :content_ref_href
      t.text :content
      t.timestamps
    end

    create_table :disa_rule_descriptions do |t|
      t.references :rule
      t.text :vuln_discussion
      t.text :false_positives
      t.text :false_negatives
      t.boolean :documentable
      t.text :mitigations
      t.text :severity_override_guidance
      t.text :potential_impacts
      t.text :third_party_tools
      t.text :mitigation_control
      t.text :responsibility
      t.text :ia_controls
      t.timestamps
    end

    create_table :rule_descriptions do |t|
      t.references :rule
      t.text :description
      t.timestamps
    end

    create_table :references do |t|
      t.string :contributor
      t.string :coverage
      t.string :creator
      t.string :date
      t.string :description
      t.string :format
      t.string :identifier
      t.string :language
      t.string :publisher
      t.string :relation
      t.string :rights
      t.string :source
      t.string :subject
      t.string :title
      t.string :type
      t.timestamps
    end
  end
end
