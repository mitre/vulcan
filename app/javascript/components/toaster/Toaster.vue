<template>
  <div />
</template>

<script>
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import _ from "lodash";

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
    if (this.notice) {
      this.alertOrNotifyResponse({
        data: {
          toast: this.notice,
        },
      });
    }

    if (this.alert) {
      this.alertOrNotifyResponse({
        data: {
          toast: {
            title: "Error",
            variant: "danger",
            message: this.alert,
          },
        },
      });
    }
  },
};
</script>

<style scoped></style>
