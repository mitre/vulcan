<template>
  <p>
    <b>{{ attr }}:</b>
    <span v-for="(segment, index) in segments" :key="index">
      <mark v-if="segment.highlighted" class="highlighted-text">{{ segment.text }}</mark>
      <span v-else>{{ segment.text }}</span>
    </span>
  </p>
</template>

<script>
import axios from "axios";
export default {
  name: "FindAndReplaceResult",
  props: {
    find: {
      type: String,
      required: true,
    },
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
    return {
      segments: [],
    };
  },
  mounted: function () {
    const normalizedValue = this.value.toLowerCase();
    const normalizedFind = this.find.toLowerCase();
    const matchIndices = [];
    let currentIndex;
    let previousIndex = 0;
    while (true) {
      currentIndex = normalizedValue.indexOf(normalizedFind, previousIndex);
      if (currentIndex < 0) {
        break;
      }
      matchIndices.push(currentIndex);
      previousIndex = currentIndex + 1;
    }
    currentIndex = 0;
    matchIndices.forEach((index) => {
      this.segments.push({ text: this.value.substring(currentIndex, index), highlighted: false });
      currentIndex = index + this.find.length;
      this.segments.push({ text: this.value.substring(index, currentIndex), highlighted: true });
    });
    this.segments.push({ text: this.value.substring(currentIndex), highlighted: false });
  },
};
</script>

<style scoped>
.highlighted-text {
  background-color: #f0dc76;
}
</style>
