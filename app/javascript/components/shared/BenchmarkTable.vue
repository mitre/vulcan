<template>
  <div>
    <ConfirmDeleteModal
      v-model="showDeleteModal"
      :item-name="itemToDelete ? itemToDelete.title || itemToDelete.name || '' : ''"
      :item-type="type.toLowerCase()"
      :is-deleting="isDeleting"
      :warning-message="`This will permanently remove this ${type} from Vulcan.`"
      @confirm="confirmDelete"
      @cancel="cancelDelete"
    />

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
        <span class="version-badge">{{ formatVersion(data.item) }}</span>
      </template>
      <template #cell(version)="data">
        <span class="version-badge">{{ formatVersion(data.item) }}</span>
      </template>
      <template #cell(severity_counts)="data">
        <SeverityBadges :counts="data.item.severity_counts" />
      </template>
      <template #cell(actions)="data">
        <TableActionButtons
          v-if="is_vulcan_admin"
          :item-name="data.item.title || data.item.name || ''"
          @delete="openDeleteModal(data.item)"
        />
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
import api from "../../api/baseApi";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { formatDate as formatDateUtil } from "../../utils/dateFormatter";
import { abbreviateSrgName as abbreviateSrgNameUtil } from "../../utils/srgNameAbbreviator";
import SeverityBadges from "./SeverityBadges.vue";
import ConfirmDeleteModal from "./ConfirmDeleteModal.vue";
import TableActionButtons from "./TableActionButtons.vue";
import { useDeleteConfirmation } from "../../composables/useDeleteConfirmation";
import { useTableSearch } from "../../composables/useTableSearch";

export default {
  name: "BenchmarkTable",
  components: { SeverityBadges, ConfirmDeleteModal, TableActionButtons },
  mixins: [FormMixinVue, AlertMixinVue],
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
  setup(props) {
    const {
      showModal: showDeleteModal,
      itemToDelete,
      isDeleting,
      openModal: openDeleteModal,
      cancel: cancelDelete,
      confirm: confirmDeleteAction,
    } = useDeleteConfirmation();

    const filterFn = (item, q) => {
      if (props.type === "Component") {
        return (item.name || "").toLowerCase().includes(q);
      }
      return (item.title || "").toLowerCase().includes(q);
    };

    const { search, perPage, currentPage, filteredItems, totalRows } = useTableSearch(
      () => props.srgs,
      filterFn,
    );

    return {
      showDeleteModal,
      itemToDelete,
      isDeleting,
      openDeleteModal,
      cancelDelete,
      confirmDeleteAction,
      search,
      perPage,
      currentPage,
      searchedCollection: filteredItems,
      rows: totalRows,
    };
  },
  data: function () {
    const fields = this.buildFields();
    const allColumnKeys = fields.map((f) => f.key);
    return {
      fields,
      visibleColumns: [...allColumnKeys],
      allColumnKeys,
    };
  },
  computed: {
    searchPlaceholder() {
      if (this.type === "Component") return "Search components by name...";
      return `Search ${this.type === "STIG" ? "STIG" : "SRG"} by title...`;
    },
    // Filter fields based on visibility
    filteredFields() {
      return this.fields.filter((f) => this.visibleColumns.includes(f.key));
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
          label: "",
          thClass: "text-center",
          tdClass: "text-center align-middle",
        });
      }
      return fields;
    },
    formatVersion(item) {
      const v = String(item.version ?? "");
      if (v.startsWith("V")) return v;
      const r = String(item.release ?? "");
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
    apiBasePath() {
      const paths = { SRG: "srgs", STIG: "stigs", Component: "components" };
      return paths[this.type] || this.type.toLowerCase() + "s";
    },
    async confirmDelete() {
      const { success, error } = await this.confirmDeleteAction(async (item) => {
        // Dynamic path computed from type (SRG/STIG/Component) — use baseApi directly
        await api.delete(`/${this.apiBasePath()}/${item.id}.json`);
      });
      if (success) {
        this.$emit("deleted");
        this.alertOrNotifyResponse({
          data: {
            toast: {
              title: "Removed",
              message: [`${this.type} removed successfully.`],
              variant: "success",
            },
          },
        });
      } else if (error) {
        this.alertOrNotifyResponse(error.response || error);
      }
    },
  },
};
</script>

<style scoped>
.version-badge {
  display: inline-block;
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace;
  font-size: 0.8rem;
  font-weight: 600;
  padding: 0.15rem 0.5rem;
  border-radius: 0.25rem;
  background-color: var(--vulcan-component-bg-alt, #e9ecef);
  color: var(--vulcan-emphasis-color, #212529);
  border: 1px solid var(--vulcan-border-color, #dee2e6);
  letter-spacing: 0.025em;
  white-space: nowrap;
}
</style>
