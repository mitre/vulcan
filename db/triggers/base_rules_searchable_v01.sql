-- Fires on INSERT and on UPDATE of exactly the columns that feed the vector.
-- searchable itself is in the list because child-table triggers write
-- searchable = NULL as the recompute signal, and the backfill does the same.
-- Updates to unrelated columns (status, locks, review flags, InSpec bodies)
-- skip the recompute entirely.
CREATE TRIGGER base_rules_searchable
    BEFORE INSERT OR UPDATE OF searchable, title, fixtext, vendor_comments,
                              status_justification, artifact_description
    ON base_rules
    FOR EACH ROW
    EXECUTE FUNCTION base_rules_searchable_trigger();
