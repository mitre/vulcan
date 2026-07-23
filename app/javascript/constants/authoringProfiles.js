/**
 * Frontend mirror of the AuthoringProfile registry's parent-eligibility
 * policy (app/models/authoring_profile.rb): srg components derive from
 * core SRGs only, stig components from derived (non-core) SRGs only.
 * The source picker filters by this so ineligible parents are never
 * offered — the backend validation still stands as the enforcement
 * layer.
 */
export function isEligibleParent(srg, documentType) {
  if (documentType === "srg") return srg.core === true;
  if (documentType === "stig") return !srg.core;
  return false;
}
