module ProjectHistoriesHelper
  def get_project_history(control_attr, history_type)
    comments = ProjectHistory.where("project_id = ? AND project_attr = ? AND history_type = ?", @project.id, control_attr, history_type).order(:created_at)
    comments.each do |comment|
      if comment.is_reply_to != -1
        comments = comments.to_a - [comment]
        comments.insert(comments.index(ProjectHistory.find(comment.is_reply_to)) + 1, comment)
      end
    end
    comments 
  end
end
