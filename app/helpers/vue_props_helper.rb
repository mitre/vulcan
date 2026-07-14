# frozen_string_literal: true

# Shared Vue props passed from HAML to every page-level Vue component.
# Centralizes current_user_id, statuses, and available_roles so adding
# a new common prop requires changing one file instead of every HAML template.
module VuePropsHelper
  # Component-scoped pages pass their component so the statuses vocabulary
  # matches its authoring profile; pages without a single component get the
  # global STIG vocabulary.
  def common_vue_props(component: nil)
    statuses = if component
                 AuthoringProfile.for(component.document_type).statuses
               else
                 RuleConstants::STATUSES
               end
    {
      'v-bind:current_user_id' => current_user.id.to_json,
      'v-bind:statuses' => statuses.to_json,
      'v-bind:available_roles' => ProjectMemberConstants::PROJECT_MEMBER_ROLES.to_json
    }
  end
end
