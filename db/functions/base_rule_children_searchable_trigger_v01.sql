-- Shared trigger body for tables whose content folds into a parent
-- base_rules row's searchable vector (checks, disa_rule_descriptions).
-- It writes searchable = NULL as a signal: the parent row's BEFORE trigger
-- recomputes the real vector in the same statement, so NULL never persists
-- and the compute logic stays in one place (base_rule_searchable_vector).
-- A re-parented child refreshes BOTH the old and new parent rows; a parent
-- deleted by cascade simply matches zero rows here.
CREATE OR REPLACE FUNCTION base_rule_children_searchable_trigger() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE base_rules SET searchable = NULL WHERE id = OLD.base_rule_id;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.base_rule_id IS DISTINCT FROM OLD.base_rule_id THEN
    UPDATE base_rules SET searchable = NULL WHERE id = OLD.base_rule_id;
  END IF;

  UPDATE base_rules SET searchable = NULL WHERE id = NEW.base_rule_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
