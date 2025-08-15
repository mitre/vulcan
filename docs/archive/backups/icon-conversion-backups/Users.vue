<template>
  <div>
    <h1>Manage Vulcan Users</h1>
    <b-col>
      <b-row>
        <b-col md="10" class="border-right">
          <UsersTable :users="users" />
        </b-col>
        <b-col>
          <div class="clickable" @click="showHistory = !showHistory">
            <h5 class="m-0 d-inline-block">User History</h5>

            <i v-if="showHistory" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
            <i v-if="!showHistory" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
          </div>
          <b-collapse id="collapse-metadata" v-model="showHistory">
            <History :histories="histories" :revertable="false" />
          </b-collapse>
        </b-col>
      </b-row>
    </b-col>
  </div>
</template>

<script>
import UsersTable from "./UsersTable.vue";
import History from "../shared/History.vue";

export default {
  name: "Users",
  components: { UsersTable, History },
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
  data: function () {
    return {
      showHistory: true,
    };
  },
};
</script>

<style scoped></style>
