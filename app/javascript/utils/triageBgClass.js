import { TRIAGE_LABELS } from "../constants/triageVocabulary";

const TRIAGE_STATUS_KEYS = new Set(Object.keys(TRIAGE_LABELS));

export function triageBgClass(triageStatus) {
  if (!triageStatus || triageStatus === "pending") return "";
  if (!TRIAGE_STATUS_KEYS.has(triageStatus)) return "";
  return `triage-bg--${triageStatus}`;
}
