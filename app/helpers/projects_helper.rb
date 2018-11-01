module ProjectsHelper
  def applicability_count
    @project.applicable_counts
  end

  def not_started_count
    controls = @project.project_controls.group_by(&:status)
    controls['Not Started'].nil? ? 0 : controls['Not Started'].count
  end

  def awaiting_review_count
    controls = @project.project_controls.group_by(&:status)
    controls['Awaiting Review'].nil? ? 0 : controls['Awaiting Review'].count
  end

  def need_changes_count
    controls = @project.project_controls.group_by(&:status)
    controls['Needs Changes'].nil? ? 0 : controls['Needs Changes'].count
  end

  def approved_count
    controls = @project.project_controls.group_by(&:status)
    controls['Approved'].nil? ? 0 : controls['Approved'].count
  end
end
