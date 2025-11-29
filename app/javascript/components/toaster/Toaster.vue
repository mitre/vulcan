<script>
import AlertMixinVue from '../../mixins/AlertMixin.vue'

export default {
  name: 'Toaster',
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
  mounted() {
    if (this.notice) {
      this.alertOrNotifyResponse({
        data: {
          toast: this.notice,
        },
      })
    }

    if (this.alert) {
      this.alertOrNotifyResponse({
        data: {
          toast: {
            title: 'Error',
            variant: 'danger',
            message: this.alert,
          },
        },
      })
    }
  },
}
</script>

<template>
  <div />
</template>

<style scoped></style>
