# frozen_string_literal: true

# Shared Vue props passed from HAML to every page-level Vue component.
# Centralizes current_user_id, statuses, and available_roles so adding
# a new common prop requires changing one file instead of every HAML template.
module VuePropsHelper
  def common_vue_props
    {
      'v-bind:current_user_id' => current_user.id.to_json,
      'v-bind:statuses' => RuleConstants::STATUSES.to_json,
      'v-bind:available_roles' => ProjectMemberConstants::PROJECT_MEMBER_ROLES.to_json
    }
  end
end
