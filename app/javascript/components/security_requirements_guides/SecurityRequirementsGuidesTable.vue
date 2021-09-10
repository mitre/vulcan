<template>
  <div>
    <b-table
      id="srgs-table"
      :items="srgs"
      :fields="fields"
    >
      <template #cell(actions)="data">
        <b-button
          class="float-right mt-1"
          variant="danger"
          data-confirm="Are you sure you want to remove this SRG from Vulcan?"
          data-method="delete"
          :href="destroyAction(data.item)"
          rel="nofollow"
        >
          <i class="mdi mdi-trash-can" aria-hidden="true" />
          Remove
        </b-button>
      </template>
    </b-table>
  </div>
</template>
<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";


export default {
  name: "SecurityRequirementsGuidesTable",
  mixins: [FormMixinVue, AlertMixinVue],
  props: {
    srgs: Array,
    required: true
  },
  data: function () {
    return {
      fields: [
        { key: "srg_id", label: "SRG ID" },
        { key: 'title', label: "Title" },
        { key: 'version', label: "Version" },
        {
          key: "actions",
          label: "Actions",
          thClass: "text-right",
          tdClass: "p-0 text-right",
        },
      ]
    }
  },
  methods: {
    destroyAction: function(srg) {
      return `/srgs/${srg.id}`
    },
    loadSrgs: function() {
      axios.get('/srgs')
      .then()
    }
  },
  watch: {
    refresh: function () {
      this.loadSrgs();
    }
  }
}
</script>
