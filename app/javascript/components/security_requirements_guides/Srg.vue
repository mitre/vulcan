<template>
  <BenchmarkViewer :benchmark="normalizedBenchmark" type="srg" />
</template>

<script>
import BenchmarkViewer from "../shared/BenchmarkViewer.vue";
import { srgToBenchmark } from "../../adapters/benchmark";

export default {
  name: "Srg",
  components: { BenchmarkViewer },
  props: {
    srg: {
      type: Object,
      required: true,
    },
  },
  computed: {
    normalizedBenchmark() {
      return srgToBenchmark(this.srg);
    },
  },
};
</script>
