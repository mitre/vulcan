-- Fires when check content enters, leaves, or moves — updates of unrelated
-- check columns skip the parent recompute.
CREATE TRIGGER checks_searchable
    AFTER INSERT OR DELETE OR UPDATE OF content, base_rule_id ON checks
    FOR EACH ROW
    EXECUTE FUNCTION base_rule_children_searchable_trigger();
