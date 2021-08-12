<template>
  <div class="row">
    <div class="col-2 leftEditorColumn">
      <ControlNavigator @controlSelected="handleControlSelected($event)" :controls="controls" :selectedControl="selectedControl" />
    </div>

    <template v-if="selectedControl != null">
      <!-- Main editor column -->
      <div class="col-6">
        <p>selected control: {{selectedControl.id}}</p>
      </div>

      <!-- Additional info column -->
      <div class="col-4">
        <ControlComments :control="selectedControl"/>
      </div>
    </template>

    <template v-else>
      <div class="col-10">
        <p>Select a control on the left to edit.</p>
      </div>
    </template>
    
  </div>
</template>

<script>
export default {
  name: 'ControlsCodeEditorView',
  props: {
    project: {
      type: Object,
      required: true,
    },
    controls: {
      type: Array,
      required: true,
    }
  },
  data: function () {
    return {
      selectedControl: null
    }
  },
  methods: {
    handleControlSelected: function(event) {
      this.selectedControl = event;
    }
  }
}
</script>

<style scoped>
</style>
