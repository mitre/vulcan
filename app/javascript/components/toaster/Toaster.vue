<template>
  <div />
</template>

<script>
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "Toaster",
  mixins: [AlertMixinVue],
  props: {
    notice: {
      type: String,
      required: false,
    },
    alert: {
      type: String,
      required: false,
    },
  },
  mounted: function () {
    this.alertOrNotifyResponse({
      data: {
        notice: this.notice,
        alert: this.alert,
      },
    });
  },
};
</script>

<style scoped></style>
