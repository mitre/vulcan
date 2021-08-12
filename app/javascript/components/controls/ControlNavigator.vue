<template>
  <div>
    <p class="controlNavigatorSection"><strong>Filter &amp; Search</strong></p>
    <div class="input-group">
      <input type="text" class="form-control" id="controlSearch" placeholder="Search controls..." v-model="search">
    </div>

    <p class="controlNavigatorSection"><strong>Open Controls</strong></p>
    <div :class="controlRowClass(control)" @click="controlSelected(control)" :key="'open-' + control.id" v-for="control in filteredOpenControls">
      <i @click.stop="removeOpenControl(control)" class="mdi mdi-close closeControlButton" aria-hidden="true"></i>
      {{control.id}}
    </div>

    <p class="controlNavigatorSection"><strong>All Controls</strong></p>
    <div :class="controlRowClass(control)" @click="controlSelected(control)" :key="'control-' + control.id" v-for="control in filteredControls">
      {{control.id}}
    </div>
  </div>
</template>


<script>

//
// Expect component to emit `controlSelected` event when
// a control is selected from the list. This event means that
// the user wants to edit that specific control. 
// this.$emit('controlSelected', control)
//
// <ControlNavigator @controlSelected="handleControlSelected($event)" ... />
//
export default {
  name: 'ControlNavigator',
  props: {
    controls: {
      type: Array,
      required: true,
    },
    selectedControl: {
      type: Object,
      required: false,
    }
  },
  data: function() {
    return {
      openControls: [],
      search: ""
    }
  },
  computed: {
    filteredControls: function() {
      return this.filterControls(this.controls).sort(this.sortById);
    },
    filteredOpenControls: function() {
      return this.filterControls(this.openControls);
    },
  },
  methods: {
    // Event handler for when a control is selected
    controlSelected: function(control) {
      this.addOpenControl(control);
      this.$emit('controlSelected', control);
    },
    // Adds a control to the `openControls` array
    addOpenControl: function(control) {
      // Guard against duplicate
      for (let i = 0; i < this.openControls.length; i++) {
        if (this.openControls[i].id == control.id) {
          return;
        }
      }
      // Push to array and re-sort
      this.openControls.push(control);
      this.openControls.sort(this.sortById);
    },
    // Removes a control from the `openControls` array
    removeOpenControl: function(control) {
      const found = this.openControls.findIndex(c => c.id == control.id);
      if (found != -1) {
        this.openControls.splice(found, 1);

        // Handle the case where the close control was the selected control
        if (control.id == this.selectedControl?.id) {
          this.$emit('controlSelected', null);
        }
      }
    },
    // Helper to sort controls by ID
    sortById(control1, control2) {
      if (control1.id < control2.id) {
        return -1;
      }
      if (control1.id > control2.id) {
        return 1;
      }
      return 0;
    },
    // Dynamically set the class of each control row
    controlRowClass: function(control) {
      return {
        controlRow: true,
        selectedControlRow: this.selectedControl?.id == control.id
      }
    },
    // Helper to filter & search a group of controls
    // PLACEHOLDER! searching by id - should be changed to title/name once implemented
    filterControls(controls) {
      let downcaseSearch = this.search.toLowerCase()
      return controls.filter(user => user.id.toString().toLowerCase().includes(downcaseSearch));
    }
   }
}
</script>

<style scoped>
.controlRow {
  cursor: pointer;
  padding: 0.25em;
}
.selectedControlRow {
  background: rgba(66, 50, 50, 0.09);
}
.controlRow:hover {
  background: rgb(0, 0, 0, 0.12);
}
.controlNavigatorSection {
  margin: 1em 0em 0em 0em;
}
.closeControlButton {
  color: red;
  padding: 0.1em;
  border: 1px solid rgb(0, 0, 0, 0);
  box-sizing: border-box
}
.closeControlButton:hover {
  border: 1px solid red;
  border-radius: 0.2em;
}
</style>
