module ProjectControlHistoriesHelper
  def get_history(type, history_type)
    comments = ProjectControlHistory.where("project_control_id = ? AND project_control_attr = ? AND history_type = ?", @project_control.id, type, history_type).order(:created_at)
    comments.each do |comment|
      if comment.is_reply_to != -1
        comments = comments.to_a - [comment]
        comments.insert(comments.index(ProjectControlHistory.find(comment.is_reply_to)) + 1, comment)
      end
    end
    comments 
  end
end
