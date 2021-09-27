class CreateReviews < ActiveRecord::Migration[6.1]
  def change
    create_table :reviews do |t|
      t.references :user, index: true
      t.references :rule, index: true
      t.string :action
      t.text :comment
      t.timestamps
    end

    add_reference :rules, :review_requestor, foreign_key: { to_table: :users }
  end
end
