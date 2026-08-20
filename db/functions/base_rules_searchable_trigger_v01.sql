-- Row trigger body for base_rules: recompute the searchable vector on every
-- INSERT and UPDATE. Runs BEFORE the write, so the value lands with the row
-- and no recursive UPDATE occurs. On INSERT the associated subqueries are
-- empty by construction (children reference the row's id via FK).
CREATE OR REPLACE FUNCTION base_rules_searchable_trigger() RETURNS trigger AS $$
BEGIN
  NEW.searchable := base_rule_searchable_vector(
    NEW.id, NEW.title, NEW.fixtext, NEW.vendor_comments,
    NEW.status_justification, NEW.artifact_description
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
