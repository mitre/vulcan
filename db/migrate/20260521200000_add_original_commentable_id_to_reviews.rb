# frozen_string_literal: true

class AddOriginalCommentableIdToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :original_commentable_id, :bigint, null: true
  end
end
