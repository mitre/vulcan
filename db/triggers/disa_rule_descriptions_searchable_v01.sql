-- Fires when searched description content enters, leaves, or moves —
-- updates of unrelated description columns skip the parent recompute.
CREATE TRIGGER disa_rule_descriptions_searchable
    AFTER INSERT OR DELETE OR UPDATE OF vuln_discussion, mitigations, base_rule_id
    ON disa_rule_descriptions
    FOR EACH ROW
    EXECUTE FUNCTION base_rule_children_searchable_trigger();
