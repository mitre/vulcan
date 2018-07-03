module ProjectHistoriesHelper
  def get_project_history(type)
    comments = ProjectHistory.where("project_id = ? AND project_attr = ?", @project.id, type).order(:created_at)
    comments.each do |comment|
      if comment.is_reply_to != -1
        comments = comments.to_a - [comment]
        comments.insert(comments.index(ProjectHistory.find(comment.is_reply_to)) + 1, comment)
      end
    end
    comments 
  end
end
