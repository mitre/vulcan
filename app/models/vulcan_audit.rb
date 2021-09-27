
class VulcanAudit < Audited::Audit
  def self.create_initial_rule_audit_from_mapping(project_id)
    {
      auditable_type: 'Rule',
      action: 'create',
      user_type: 'System',
      audited_changes: {
        project_id: project_id
      }
    }
  end
end
