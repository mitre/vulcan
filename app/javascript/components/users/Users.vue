<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <!-- No actions for now -->
      </template>
      <template #right>
        <b-button-group size="sm">
          <b-button
            :variant="isPanelActive('user-history') ? 'secondary' : 'outline-secondary'"
            @click="togglePanel('user-history')"
          >
            <b-icon icon="clock-history" /> User Activity
          </b-button>
        </b-button-group>
      </template>
    </BaseCommandBar>

    <UsersTable :users="users" />

    <!-- User History Slideover -->
    <b-sidebar
      id="user-history-sidebar"
      title="User Activity"
      right
      shadow
      backdrop
      :visible="activePanel === 'user-history'"
      @hidden="closePanel"
    >
      <div class="px-3 py-2">
        <History :histories="histories" :revertable="false" />
      </div>
    </b-sidebar>
  </div>
</template>

<script>
import UsersTable from "./UsersTable.vue";
import History from "../shared/History.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import { useSidebar } from "../../composables";

export default {
  name: "Users",
  components: { UsersTable, History, BaseCommandBar },
  setup() {
    const { activePanel, togglePanel, closePanel } = useSidebar();
    return { activePanel, togglePanel, closePanel };
  },
  props: {
    users: {
      type: Array,
      required: true,
    },
    histories: {
      type: Array,
      required: true,
    },
  },
  computed: {
    breadcrumbs() {
      return [{ text: 'Users', active: true }];
    },
    isPanelActive() {
      return (panel) => this.activePanel === panel;
    },
  },
};
</script>

<style scoped></style>
