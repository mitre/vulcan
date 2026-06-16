export function groupCommentsByRule(comments) {
  const groups = [];
  const seen = new Map();

  for (const c of comments) {
    const key = c.group_rule_displayed_name || c.rule_displayed_name || "(component)";
    if (!seen.has(key)) {
      const group = {
        key,
        ruleName: key,
        srgInfo: c.srg_info || null,
        comments: [],
        pendingCount: 0,
      };
      seen.set(key, group);
      groups.push(group);
    }
    const g = seen.get(key);
    g.comments.push(c);
    if (c.triage_status === "pending") g.pendingCount++;
  }

  return groups.sort((a, b) => {
    const aComp = a.key === "(component)";
    const bComp = b.key === "(component)";
    if (aComp && !bComp) return -1;
    if (!aComp && bComp) return 1;
    return a.ruleName.localeCompare(b.ruleName, undefined, { numeric: true });
  });
}
