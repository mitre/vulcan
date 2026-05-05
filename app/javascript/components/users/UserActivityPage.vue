<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <h5 class="mb-0"><b-icon icon="clock-history" class="mr-1" /> Activity</h5>
        <small class="text-muted">
          The 50 most recent actions you've taken in Vulcan (creating projects, editing components,
          submitting reviews, etc.)
        </small>
      </b-card-header>
      <b-card-body>
        <p v-if="histories.length === 0" class="text-muted mb-0">
          No activity yet. Your actions will appear here.
        </p>
        <History v-else :histories="histories" :revertable="false" />
      </b-card-body>
    </b-card>
  </div>
</template>

<script>
import History from "../shared/History.vue";

export default {
  name: "UserActivityPage",
  components: { History },
  props: {
    histories: { type: Array, default: () => [] },
  },
};
</script>
