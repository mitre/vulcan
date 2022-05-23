<template>
  <div>
    <b-table id="srgs-table" :items="srgs" :fields="fields">
      <template #cell(actions)="data">
        <b-button
          v-if="is_vulcan_admin"
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
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "SecurityRequirementsGuidesTable",
  mixins: [FormMixinVue],
  props: {
    srgs: {
      type: Array,
      required: true,
    },
    is_vulcan_admin: {
      type: Boolean,
      required: true,
    },
  },
  data: function () {
    const fields = [
      { key: "srg_id", label: "SRG ID" },
      { key: "title", label: "Title" },
      { key: "version", label: "Version" },
      { key: "release_date", label: "Release Date" },
    ];
    if (this.is_vulcan_admin) {
      fields.push({
        key: "actions",
        label: "Actions",
        thClass: "text-right",
        tdClass: "p-0 text-right",
      });
    }
    return {
      fields,
    };
  },
  watch: {
    refresh: function () {
      this.loadSrgs();
    },
  },
  methods: {
    destroyAction: function (srg) {
      return `/srgs/${srg.id}`;
    },
  },
};
</script>
