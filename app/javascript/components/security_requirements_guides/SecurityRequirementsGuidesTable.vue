<template>
  <div>
    <b-table id="srgs-table" :items="srgs" :fields="fields">
      <template v-if="type === 'STIG'" #cell(stig_id)="data">
        <b-link :href="`/stigs/${data.item.id}`">{{ data.item.stig_id }}</b-link>
      </template>
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
    type: {
      type: String,
      default: "SRG",
    },
  },
  data: function () {
    const fields = [
      this.type === "SRG"
        ? { key: "srg_id", label: "SRG ID" }
        : { key: "stig_id", label: "STIG ID" },
      { key: "title", label: "Title" },
      { key: "version", label: "Version" },
      this.type === "SRG"
        ? { key: "release_date", label: "Release Date" }
        : { key: "benchmark_date", label: "Benchmark Date" },
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
    destroyAction: function (item) {
      return `/${this.type === "SRG" ? "srgs" : "stigs"}/${item.id}`;
    },
  },
};
</script>
