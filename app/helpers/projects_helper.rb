module ProjectsHelper
  def get_applicability_count
    controls = @project.project_controls.group_by {|control| control.applicability }
    app_conf_count     = controls['Applicable - Configurable'].nil? ? 0 : controls['Applicable - Configurable'].count
    app_dnm_count      = controls['Applicable - Does Not Meet'].nil? ? 0 : controls['Applicable - Does Not Meet'].count
    app_im_count       = controls['Applicable - Inherently Meets'].nil? ? 0 : controls['Applicable - Inherently Meets'].count
    not_app_count      = controls['Not Applicable'].nil? ? 0 : controls['Not Applicable'].count
    not_yet_set_count  = controls[nil].nil? ? 0 : controls[nil].count
    {'results' => data = [
      JSON.parse({label: "Applicable - Configurable", value: app_conf_count }.to_json),
      JSON.parse({label: "Applicable - Does Not Meet", value: app_dnm_count }.to_json),
      JSON.parse({label: "Not Applicable", value: not_app_count }.to_json),
      JSON.parse({label: "Applicable - Inherently Meets", value: app_im_count }.to_json),
      JSON.parse({label: "Not Yet Set", value: not_yet_set_count }.to_json)
    ]}.to_json
  end
  
  def get_not_started_count
    controls = @project.project_controls.group_by {|control| control.status }
    controls['Not Started'].nil? ? 0 : controls['Not Started'].count
  end
  
  def get_awaiting_review_count
    controls = @project.project_controls.group_by {|control| control.status }
    controls['Awaiting Review'].nil? ? 0 : controls['Awaiting Review'].count
  end
  
  def get_need_changes_count
    controls = @project.project_controls.group_by {|control| control.status }
    controls['Needs Changes'].nil? ? 0 : controls['Needs Changes'].count
  end
  
  def get_approved_count
    controls = @project.project_controls.group_by {|control| control.status }
    controls['Approved'].nil? ? 0 : controls['Approved'].count
  end
end
