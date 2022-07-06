<template>
  <p v-if="value">
    <b> {{ attr }} </b> {{ value }}
  </p>
</template>

<script>
import axios from "axios";
export default {
  name: "FindAndReplaceResult",
  props: {
    attr: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      required: false,
    },
  },
  data: function () {
    return {};
  },
  methods: {},
};
</script>

<style scoped></style>
