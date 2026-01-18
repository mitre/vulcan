<script>
import History from '../shared/History.vue'
import UsersTable from './UsersTable.vue'

export default {
  name: 'Users',
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
  data() {
    return {
      showHistory: true,
    }
  },
}
</script>

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
            <h5 class="m-0 d-inline-block">
              User History
            </h5>

            <i v-if="showHistory" class="bi bi-chevron-down" aria-hidden="true" />
            <i v-if="!showHistory" class="bi bi-chevron-up" aria-hidden="true" />
          </div>
          <b-collapse id="collapse-metadata" v-model="showHistory">
            <History :histories="histories" :revertable="false" />
          </b-collapse>
        </b-col>
      </b-row>
    </b-col>
  </div>
</template>

<style scoped></style>
