module ProjectControlHistoriesHelper
  def get_history(type)
    comments = ProjectControlHistory.where("project_control_id = ? AND project_control_attr = ?", @project_control.id, type).order(:created_at)
    comments.each do |comment|
      if comment.is_reply_to != -1
        comments = comments.to_a - [comment]
        comments.insert(comments.index(ProjectControlHistory.find(comment.is_reply_to)) + 1, comment)
      end
    end
    comments 
  end
end
