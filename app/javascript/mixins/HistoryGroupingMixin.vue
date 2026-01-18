<script>
// This mixins is to group histories components by name, created_at and comments.
export default {
  methods: {
    roundToNearestMinute(dateString) {
      const date = new Date(dateString)
      date.setSeconds(0)
      date.setMilliseconds(0)
      return date.toISOString()
    },
    groupHistories(histories) {
      const grouped = {}

      histories.forEach((history) => {
        const roundedCreatedAt = this.roundToNearestMinute(history.created_at)
        const key = `${history.name}-${roundedCreatedAt}-${history.comment}`
        if (!grouped[key]) {
          grouped[key] = {
            id: key,
            history,
            histories: [],
          }
        }
        grouped[key].histories.push(history)
      })

      return Object.values(grouped)
    },
  },
}
</script>
