export function triageBgClass(triageStatus) {
  if (!triageStatus || triageStatus === "pending") return "";
  return `triage-bg--${triageStatus}`;
}
