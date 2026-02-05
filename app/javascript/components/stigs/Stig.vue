<template>
  <BenchmarkViewer :benchmark="stig" type="stig" />
</template>

<script>
import BenchmarkViewer from "../shared/BenchmarkViewer.vue";

export default {
  name: "Stigs",
  components: { BenchmarkViewer },
  props: {
    stig: {
      type: Object,
      required: true,
    },
  },
};
</script>
