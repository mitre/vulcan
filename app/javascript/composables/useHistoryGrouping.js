export function useHistoryGrouping() {
  function roundToNearestInterval(dateString, intervalMs = 5000) {
    const ms = new Date(dateString).getTime();
    return new Date(Math.round(ms / intervalMs) * intervalMs).toISOString();
  }

  function groupHistories(histories) {
    const grouped = {};

    histories.forEach((history) => {
      const roundedCreatedAt = roundToNearestInterval(history.created_at);
      const key = `${history.name}-${roundedCreatedAt}-${history.comment}`;
      if (!grouped[key]) {
        grouped[key] = {
          id: key,
          history: history,
          histories: [],
        };
      }
      grouped[key].histories.push(history);
    });

    return Object.values(grouped);
  }

  return { groupHistories, roundToNearestInterval };
}
