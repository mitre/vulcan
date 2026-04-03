<template>
  <BenchmarkViewer :benchmark="normalizedBenchmark" type="stig" />
</template>

<script>
import BenchmarkViewer from "../shared/BenchmarkViewer.vue";
import { stigToBenchmark } from "../../adapters/benchmark";

export default {
  name: "Stigs",
  components: { BenchmarkViewer },
  props: {
    stig: {
      type: Object,
      required: true,
    },
  },
  computed: {
    normalizedBenchmark() {
      return stigToBenchmark(this.stig);
    },
  },
};
</script>
