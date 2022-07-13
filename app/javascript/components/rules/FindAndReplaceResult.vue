<template>
  <div class="mb-3">
    <b-row>
      <b-col lg="2" class="mb-2">
        <h6 class="mb-0">{{ field }}</h6>
      </b-col>
      <b-col lg="8" class="mb-2">
        <span v-for="(segment, index) in segments" :key="index">
          <mark v-if="segment.highlighted" class="highlighted-text">
            <del>{{ segment.text }}</del>
          </mark>
          <span v-else>{{ segment.text }}</span>
        </span>
      </b-col>
      <b-col lg="2" class="text-right">
        <b-btn size="sm" @click="$emit('replace_one')">Replace</b-btn>
      </b-col>
    </b-row>
  </div>
</template>

<script>
import axios from "axios";
export default {
  name: "FindAndReplaceResult",
  props: {
    field: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      required: false,
    },
    find: {
      type: String,
      required: true,
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
