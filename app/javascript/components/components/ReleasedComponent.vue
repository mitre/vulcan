<template>
  <BenchmarkViewer :benchmark="normalizedBenchmark" type="component" />
</template>

<script>
import BenchmarkViewer from "../shared/BenchmarkViewer.vue";
import { componentToBenchmark } from "../../adapters/benchmark";

export default {
  name: "ReleasedComponent",
  components: { BenchmarkViewer },
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  computed: {
    normalizedBenchmark() {
      return componentToBenchmark(this.component);
    },
  },
};
</script>
