function normalizeTimestamp(raw) {
  return String(raw).replace(/ UTC$/, "Z").replace(" ", "T");
}

export function useDateFormat() {
  function friendlyDateTime(raw) {
    if (!raw) return "";
    return new Date(normalizeTimestamp(raw)).toLocaleString();
  }

  function friendlyDate(raw) {
    if (!raw) return "";
    return new Date(normalizeTimestamp(raw)).toLocaleDateString();
  }

  function relativeTime(raw) {
    if (!raw) return "";
    const diff = Date.now() - new Date(normalizeTimestamp(raw)).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
  }

  return { friendlyDateTime, friendlyDate, relativeTime };
}
