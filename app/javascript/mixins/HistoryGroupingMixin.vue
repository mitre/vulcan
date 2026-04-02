<script>
// This mixin groups history entries by name, timestamp, and comment.
// Audits from the same save (Rule + RuleDescription) are grouped together
// by rounding timestamps to the nearest 5-second window.
export default {
  methods: {
    roundToNearestInterval(dateString, intervalMs = 5000) {
      const ms = new Date(dateString).getTime();
      return new Date(Math.round(ms / intervalMs) * intervalMs).toISOString();
    },
    groupHistories(histories) {
      const grouped = {};

      histories.forEach((history) => {
        const roundedCreatedAt = this.roundToNearestInterval(history.created_at);
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
    },
  },
};
</script>
