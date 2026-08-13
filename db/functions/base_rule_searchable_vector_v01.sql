-- The single source of truth for a requirement row's full-text vector.
-- Weights mirror the application's search relevance: title (A), fixtext (B),
-- vendor_comments/status_justification (C), artifact_description (D).
-- Associated content (check text, DISA description discussion/mitigations)
-- is folded in unweighted, which PostgreSQL ranks as weight D.
CREATE OR REPLACE FUNCTION base_rule_searchable_vector(
  p_id bigint,
  p_title text,
  p_fixtext text,
  p_vendor_comments text,
  p_status_justification text,
  p_artifact_description text
) RETURNS tsvector AS $$
  SELECT setweight(to_tsvector('english', coalesce(p_title, '')), 'A') ||
         setweight(to_tsvector('english', coalesce(p_fixtext, '')), 'B') ||
         setweight(to_tsvector('english', coalesce(p_vendor_comments, '')), 'C') ||
         setweight(to_tsvector('english', coalesce(p_status_justification, '')), 'C') ||
         setweight(to_tsvector('english', coalesce(p_artifact_description, '')), 'D') ||
         to_tsvector('english',
           coalesce((SELECT string_agg(coalesce(c.content, ''), ' ')
                       FROM checks c WHERE c.base_rule_id = p_id), '') || ' ' ||
           coalesce((SELECT string_agg(coalesce(d.vuln_discussion, '') || ' ' || coalesce(d.mitigations, ''), ' ')
                       FROM disa_rule_descriptions d WHERE d.base_rule_id = p_id), '')
         )
$$ LANGUAGE SQL STABLE;
