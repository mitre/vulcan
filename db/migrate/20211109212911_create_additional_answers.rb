class CreateAdditionalAnswers < ActiveRecord::Migration[6.1]
  def change
    create_table :additional_answers do |t|
      t.references :rule, null: false, foreign_key: { to_table: :base_rules }
      t.references :additional_question, null: false, foreign_key: true
      t.text :answer

      t.index [:rule_id, :additional_question_id], unique: true

      t.timestamps
    end
  end
end
