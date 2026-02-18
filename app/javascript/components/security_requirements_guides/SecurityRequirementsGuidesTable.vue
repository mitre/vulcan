<template>
  <div>
    <!-- SRG/STIG/Component search -->
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
            :placeholder="searchPlaceholder"
          />
        </div>
      </div>
    </div>
    <br />
    <b-table
      id="srgs-table"
      :items="searchedCollection"
      :fields="filteredFields"
      :per-page="perPage"
      :current-page="currentPage"
    >
      <template v-if="type === 'STIG'" #cell(stig_id)="data">
        <b-link :href="`/stigs/${data.item.id}`">{{ data.item.stig_id }}</b-link>
      </template>
      <template v-else-if="type === 'Component'" #cell(name)="data">
        <b-link :href="`/components/${data.item.id}`">{{ data.item.name }}</b-link>
      </template>
      <template v-else #cell(srg_id)="data">
        <b-link :href="`/srgs/${data.item.id}`">{{ data.item.srg_id }}</b-link>
      </template>
      <template v-if="type === 'Component'" #cell(based_on_title)="data">
        <span
          v-b-tooltip.hover.html
          :title="`${data.item.based_on_title} ${data.item.based_on_version}`"
        >
          {{ abbreviateSrgName(data.item.based_on_title) }} {{ data.item.based_on_version }}
        </span>
      </template>
      <template v-if="type === 'Component'" #cell(component_version)="data">
        {{ formatVersion(data.item) }}
      </template>
      <template #cell(severity_counts)="data">
        <div v-if="data.item.severity_counts" class="d-flex" style="gap: 0.25rem">
          <div
            v-if="data.item.severity_counts.high > 0"
            class="border border-danger px-2 py-1 rounded"
          >
            <span class="text-danger font-weight-bold">CAT I</span>
            <b-badge variant="light" class="ml-1">{{ data.item.severity_counts.high }}</b-badge>
          </div>
          <div
            v-if="data.item.severity_counts.medium > 0"
            class="border border-warning px-2 py-1 rounded"
          >
            <span class="text-warning font-weight-bold">CAT II</span>
            <b-badge variant="light" class="ml-1">{{ data.item.severity_counts.medium }}</b-badge>
          </div>
          <div
            v-if="data.item.severity_counts.low > 0"
            class="border border-success px-2 py-1 rounded"
          >
            <span class="text-success font-weight-bold">CAT III</span>
            <b-badge variant="light" class="ml-1">{{ data.item.severity_counts.low }}</b-badge>
          </div>
        </div>
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
import { formatDate as formatDateUtil } from "../../utils/dateFormatter";
import { abbreviateSrgName as abbreviateSrgNameUtil } from "../../utils/srgNameAbbreviator";

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
    const fields = this.buildFields();
    const allColumnKeys = fields.map((f) => f.key);
    return {
      fields,
      perPage,
      currentPage,
      search,
      visibleColumns: [...allColumnKeys], // All columns visible by default
      allColumnKeys,
    };
  },
  computed: {
    searchPlaceholder() {
      if (this.type === "Component") return "Search components by name...";
      return `Search ${this.type === "STIG" ? "STIG" : "SRG"} by title...`;
    },
    searchedCollection: function () {
      let downcaseSearch = this.search.toLowerCase();
      if (this.type === "Component") {
        return this.srgs.filter((item) => (item.name || "").toLowerCase().includes(downcaseSearch));
      }
      return this.srgs.filter((srg) => (srg.title || "").toLowerCase().includes(downcaseSearch));
    },
    // Used by b-pagination to know how many total rows there are
    rows: function () {
      return this.srgs.length;
    },
    // Filter fields based on visibility
    filteredFields() {
      return this.fields.filter((f) => this.visibleColumns.includes(f.key));
    },
  },
  watch: {
    refresh: function () {
      this.loadSrgs();
    },
  },
  methods: {
    buildFields() {
      if (this.type === "Component") {
        return [
          { key: "name", label: "Name", sortable: true },
          { key: "based_on_title", label: "Based On", sortable: true },
          { key: "component_version", label: "Version", sortable: true },
          { key: "severity_counts", label: "Severity" },
          { key: "updated_at", label: "Updated", sortable: true, formatter: this.formatDate },
        ];
      }

      const fields = [
        this.type === "SRG"
          ? { key: "srg_id", label: "SRG ID", sortable: true }
          : { key: "stig_id", label: "STIG ID", sortable: true },
        { key: "title", label: "Title", sortable: true },
        { key: "version", label: "Version", sortable: true },
        { key: "severity_counts", label: "Severity" },
        this.type === "SRG"
          ? {
              key: "release_date",
              label: "Release Date",
              sortable: true,
              formatter: this.formatDate,
            }
          : {
              key: "benchmark_date",
              label: "Benchmark Date",
              sortable: true,
              formatter: this.formatDate,
            },
      ];
      if (this.is_vulcan_admin) {
        fields.push({
          key: "actions",
          label: "Actions",
          thClass: "text-right",
          tdClass: "p-0 text-right",
        });
      }
      return fields;
    },
    formatVersion(item) {
      const v = item.version ?? "";
      const r = item.release ?? "";
      return `V${v}R${r}`;
    },
    formatDate(value) {
      return formatDateUtil(value);
    },
    abbreviateSrgName(value) {
      return abbreviateSrgNameUtil(value);
    },
    toggleColumn(columnKey) {
      const index = this.visibleColumns.indexOf(columnKey);
      if (index > -1) {
        this.visibleColumns.splice(index, 1);
      } else {
        this.visibleColumns.push(columnKey);
      }
    },
    isColumnVisible(columnKey) {
      return this.visibleColumns.includes(columnKey);
    },
    destroyAction: function (item) {
      return `/${this.type === "SRG" ? "srgs" : "stigs"}/${item.id}`;
    },
  },
};
</script>
