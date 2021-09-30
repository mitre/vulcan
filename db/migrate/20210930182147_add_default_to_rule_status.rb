class AddDefaultToRuleStatus < ActiveRecord::Migration[6.1]
  def change
    change_column_default(
      :rules,
      :status,
      from: nil,
      to: "Not Yet Determined"
    )
  end
end
