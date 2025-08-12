<template>
  <div>
    <!-- SRG/STIG search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text">
              <b-icon icon="search" aria-hidden="true" />
            </div>
          </div>
          <input
            id="srgSearch"
            v-model="search"
            type="text"
            class="form-control"
            :placeholder="`Search ${type === 'STIG' ? 'STIG' : 'SRG'} by title...`"
          />
        </div>
      </div>
    </div>
    <br />
    <b-table
      id="srgs-table"
      :items="searchedCollection"
      :fields="fields"
      :per-page="perPage"
      :current-page="currentPage"
    >
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
          <b-icon icon="trash" aria-hidden="true" />
          Remove
        </b-button>
      </template>
    </b-table>
    <!-- Pagination controls -->
    <b-pagination
      v-model="currentPage"
      :total-rows="rows"
      :per-page="perPage"
      aria-controls="srgs-table"
    />
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
    const search = "";
    const perPage = 10;
    const currentPage = 1;
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
      perPage,
      currentPage,
      search,
    };
  },
  computed: {
    // Search SRG/STIG by title
    searchedCollection: function () {
      let downcaseSearch = this.search.toLowerCase();
      return this.srgs.filter((srg) => srg.title.toLowerCase().includes(downcaseSearch));
    },
    // Used by b-pagination to know how many total rows there are
    rows: function () {
      return this.srgs.length;
    },
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
