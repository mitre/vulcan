export function useDateFormat() {
  function friendlyDateTime(iso) {
    if (!iso) return "";
    return new Date(iso).toLocaleString();
  }

  function friendlyDate(iso) {
    if (!iso) return "";
    return new Date(iso).toLocaleDateString();
  }

  function relativeTime(iso) {
    if (!iso) return "";
    const diff = Date.now() - new Date(iso).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
  }

  return { friendlyDateTime, friendlyDate, relativeTime };
}
