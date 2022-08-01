<template>
  <div class="mb-3">
    <b-row>
      <b-col lg="2" class="mb-2">
        <h6 class="mb-0">{{ field }}</h6>
      </b-col>
      <b-col lg="8" class="mb-2">
        <span v-for="(segment, index) in segments" :key="index">
          <span v-if="segment.highlighted">
            <del
              ><span class="text-highlighted-red">{{ segment.text }}</span></del
            ><span class="text-highlighted-green">{{ replace }}</span>
          </span>
          <span v-else>{{ segment.text }}</span>
        </span>
      </b-col>
      <b-col lg="2" class="text-right">
        <CommentModal
          title="Replace"
          message="Provide a comment that summarizes your changes to this control."
          :require-non-empty="false"
          button-text="Replace"
          button-variant="secondary"
          button-size="sm"
          :button-disabled="disabled"
          wrapper-class="d-inline-block"
          @comment="$emit('replace_one', $event)"
        />
      </b-col>
    </b-row>
  </div>
</template>

<script>
import axios from "axios";
import CommentModal from "../shared/CommentModal.vue";

export default {
  name: "FindAndReplaceResult",
  components: { CommentModal },
  props: {
    field: {
      type: String,
      required: true,
    },
    segments: {
      type: Array,
      required: true,
    },
    replace: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
  },
};
</script>

<style scoped>
.text-highlighted-red {
  background-color: #e39d9b;
}

.text-highlighted-green {
  background-color: #abd5ac;
}
</style>
