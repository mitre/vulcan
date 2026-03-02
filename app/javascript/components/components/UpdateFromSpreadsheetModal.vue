<template>
  <span>
    <!-- Opener button -->
    <b-button
      class="mr-2"
      variant="outline-warning"
      size="sm"
      data-testid="update-from-spreadsheet-btn"
      @click="showModal()"
    >
      <b-icon icon="file-earmark-spreadsheet" /> Update from Spreadsheet
    </b-button>

    <!-- Multi-step modal -->
    <b-modal
      ref="modal"
      :title="modalTitle"
      :size="modalSize"
      :ok-title="modalOkTitle"
      :ok-disabled="modalOkDisabled"
      :cancel-title="modalCancelTitle"
      :cancel-disabled="step === 4"
      :no-close-on-backdrop="step === 4"
      :no-close-on-esc="step === 4"
      data-testid="update-spreadsheet-modal"
      @ok="onModalOk"
      @cancel="onModalCancel"
      @hidden="onHidden"
    >
      <!-- Step 1: File Select -->
      <div v-if="step === 1" data-testid="step-file-select">
        <b-form-group label="Select CSV or XLSX file exported from this component">
          <b-form-file
            v-model="selectedFile"
            placeholder="Choose a file..."
            accept=".csv,.xlsx"
            data-testid="file-input"
          />
        </b-form-group>

        <b-alert v-if="fileError" variant="danger" show data-testid="file-error">
          {{ fileError }}
        </b-alert>

        <p class="small text-muted">
          <strong>Tip:</strong> Export this component as CSV, modify the rules in a spreadsheet,
          then upload to update. Locked rules will not be changed.
        </p>
      </div>

      <!-- Step 2: Preview -->
      <div v-if="step === 2" class="preview-scroll" data-testid="step-preview">
        <b-alert
          v-if="previewData.warnings && previewData.warnings.length"
          variant="warning"
          show
          data-testid="preview-warnings"
        >
          <strong>Warnings:</strong>
          <ul class="mb-0">
            <li v-for="(warn, idx) in previewData.warnings" :key="idx">{{ warn }}</li>
          </ul>
        </b-alert>

        <!-- No changes message -->
        <b-alert v-if="!hasUpdates" variant="success" show data-testid="no-changes-message">
          <b-icon icon="check-circle" />
          Your spreadsheet matches the current component. No rules need updating.
        </b-alert>

        <!-- Updated rules -->
        <b-card v-if="previewData.updated.length" class="mb-3">
          <template #header>
            <strong>Updated Rules</strong>
            <b-badge variant="primary" class="ml-2">{{ previewData.updated.length }}</b-badge>
          </template>
          <b-table
            small
            hover
            :items="updatedTableItems"
            :fields="previewFields"
            data-testid="updated-rules-table"
          >
            <template #cell(changes)="data">
              <div v-for="(change, field) in data.item.changes" :key="field" class="mb-2">
                <strong class="small">{{ field }}</strong>
                <div class="diff-old rounded px-2 py-1 mt-1 small text-monospace">
                  <span class="diff-prefix">&minus;</span>
                  <span
                    v-for="(seg, i) in precomputedDiffs[data.item.rule_id][field].old"
                    :key="'o' + i"
                    :class="{ 'diff-highlight-old': seg.changed }"
                    >{{ seg.text }}</span
                  >
                </div>
                <div class="diff-new rounded px-2 py-1 mt-1 small text-monospace">
                  <span class="diff-prefix">+</span>
                  <span
                    v-for="(seg, i) in precomputedDiffs[data.item.rule_id][field].new"
                    :key="'n' + i"
                    :class="{ 'diff-highlight-new': seg.changed }"
                    >{{ seg.text }}</span
                  >
                </div>
              </div>
            </template>
          </b-table>
        </b-card>

        <!-- Unchanged rules -->
        <b-card v-if="previewData.unchanged.length" class="mb-3">
          <template #header>
            <strong>Unchanged Rules</strong>
          </template>
          <small class="text-muted">
            {{ previewData.unchanged.length }} rules have no changes
          </small>
        </b-card>

        <!-- Skipped (locked/inherited) rules -->
        <b-card v-if="previewData.skipped_locked.length" class="mb-3" border-variant="warning">
          <template #header>
            <strong>Protected Rules (Skipped)</strong>
            <b-badge variant="warning" class="ml-2">
              {{ previewData.skipped_locked.length }}
            </b-badge>
          </template>
          <ul class="mb-0 small list-unstyled">
            <li v-for="(skip, idx) in previewData.skipped_locked" :key="idx">
              <strong>{{ skip.rule_id }}</strong>
              <span v-if="skip.reason === 'inherited'" class="text-muted">
                — inherited (read-only)
              </span>
              <span v-else-if="skip.reason === 'locked'" class="text-muted"> — locked </span>
              <span v-else-if="skip.skipped_fields" class="text-muted">
                — section locked: {{ skip.skipped_fields.join(", ") }}
              </span>
              <span v-else class="text-muted"> — {{ skip.reason }} </span>
            </li>
          </ul>
        </b-card>

        <!-- Summary -->
        <b-alert v-if="hasUpdates" variant="info" show class="mt-2">
          <strong>Summary:</strong>
          {{ previewData.updated.length }} updates, {{ previewData.unchanged.length }} unchanged,
          {{ previewData.skipped_locked.length }} locked (skipped)
        </b-alert>
      </div>

      <!-- Step 3: Confirm -->
      <div v-if="step === 3" data-testid="step-confirm">
        <p>
          Are you sure you want to update
          <strong>{{ previewData.updated.length }} rules</strong>?
        </p>
        <p class="text-muted small">
          <strong>{{ previewData.skipped_locked.length }}</strong> locked rules will be skipped.
        </p>
        <p class="text-muted small">
          This action cannot be undone. All changes will be logged in the audit trail.
        </p>
      </div>

      <!-- Step 4: Progress -->
      <div v-if="step === 4" class="text-center py-4" data-testid="step-progress">
        <b-spinner label="Updating rules..." data-testid="progress-spinner" />
        <p class="mt-3">Updating {{ previewData.updated.length }} rules from spreadsheet...</p>
      </div>

      <!-- Step 5: Results -->
      <div v-if="step === 5" data-testid="step-results">
        <b-alert v-if="updateResult && updateResult.success" variant="success" show>
          <b-icon icon="check-circle" />
          {{ updateResult.message }}
        </b-alert>
        <b-alert v-if="updateResult && !updateResult.success" variant="danger" show>
          <b-icon icon="exclamation-circle" />
          {{ updateResult.message }}
        </b-alert>
        <p v-if="updateResult && updateResult.success" class="text-muted small mt-3">
          The component and its audit trail have been updated.
        </p>
        <p v-if="updateResult && !updateResult.success" class="text-muted small mt-3">
          No changes were made. Please check your file and try again.
        </p>
      </div>
    </b-modal>
  </span>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "UpdateFromSpreadsheetModal",
  mixins: [AlertMixinVue],
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      step: 1,
      selectedFile: null,
      fileError: null,
      previewData: {
        updated: [],
        unchanged: [],
        skipped_locked: [],
        warnings: [],
      },
      updateInProgress: false,
      updateResult: null,
      previewFields: [
        { key: "rule_id", label: "Rule ID", sortable: true },
        { key: "srg_id", label: "SRG ID", sortable: true },
        { key: "changes", label: "Changes" },
      ],
    };
  },
  computed: {
    hasUpdates() {
      return this.previewData.updated.length > 0;
    },
    modalTitle() {
      switch (this.step) {
        case 1:
          return "Update Rules from Spreadsheet";
        case 2:
          return this.hasUpdates
            ? `Review Changes \u2014 ${this.previewData.updated.length} rules to update`
            : "No Changes Detected";
        case 3:
          return "Confirm Update";
        case 4:
          return "Updating rules...";
        case 5:
          return this.updateResult && this.updateResult.success
            ? "Update Complete"
            : "Update Failed";
        default:
          return "Update from Spreadsheet";
      }
    },
    modalSize() {
      return this.step === 2 ? "xl" : "md";
    },
    modalOkTitle() {
      switch (this.step) {
        case 1:
          return this.updateInProgress ? "Loading..." : "Preview";
        case 2:
          return this.hasUpdates ? "Apply Changes" : "Done";
        case 3:
          return "Yes, Update";
        case 5:
          return "Close";
        default:
          return "OK";
      }
    },
    modalOkDisabled() {
      switch (this.step) {
        case 1:
          return !this.selectedFile || this.updateInProgress;
        case 4:
          return true;
        default:
          return false;
      }
    },
    modalCancelTitle() {
      switch (this.step) {
        case 2:
          return "Back";
        case 3:
          return "Back";
        default:
          return "Cancel";
      }
    },
    updatedTableItems() {
      return this.previewData.updated.map((item) => ({
        rule_id: item.rule_id,
        srg_id: item.srg_id,
        changes: item.changes,
      }));
    },
    // Precompute LCS diffs to avoid O(m*n) computation per render cycle in v-for
    precomputedDiffs() {
      const cache = {};
      this.updatedTableItems.forEach((item) => {
        cache[item.rule_id] = {};
        Object.entries(item.changes).forEach(([field, change]) => {
          cache[item.rule_id][field] = this.diffWords(change.from, change.to);
        });
      });
      return cache;
    },
  },
  methods: {
    showModal() {
      this.resetModal();
      this.$refs.modal.show();
    },
    resetModal() {
      this.step = 1;
      this.selectedFile = null;
      this.fileError = null;
      this.previewData = {
        updated: [],
        unchanged: [],
        skipped_locked: [],
        warnings: [],
      };
      this.updateInProgress = false;
      this.updateResult = null;
    },
    onModalOk(bvModalEvt) {
      switch (this.step) {
        case 1:
          bvModalEvt.preventDefault();
          this.fetchPreview();
          break;
        case 2:
          if (this.hasUpdates) {
            bvModalEvt.preventDefault();
            this.step = 3;
          }
          // No updates: let modal close naturally
          break;
        case 3:
          bvModalEvt.preventDefault();
          this.applyChanges();
          break;
        case 5:
          this.onResultsClose();
          break;
      }
    },
    onModalCancel(bvModalEvt) {
      if (this.step === 2 || this.step === 3) {
        bvModalEvt.preventDefault();
        this.step = this.step === 3 ? 2 : 1;
      }
    },
    onHidden() {
      this.resetModal();
    },
    fetchPreview() {
      if (!this.selectedFile) {
        this.fileError = "Please select a file";
        return;
      }

      this.fileError = null;
      this.updateInProgress = true;

      const formData = new FormData();
      formData.append("file", this.selectedFile);

      return axios
        .post(`/components/${this.component.id}/preview_spreadsheet_update`, formData, {
          headers: { "Content-Type": "multipart/form-data" },
        })
        .then((response) => {
          this.previewData = response.data;
          this.step = 2;
        })
        .catch((error) => {
          this.fileError =
            (error.response && error.response.data && error.response.data.error) ||
            "Failed to preview spreadsheet";
        })
        .finally(() => {
          this.updateInProgress = false;
        });
    },
    applyChanges() {
      this.step = 4;

      const formData = new FormData();
      formData.append("file", this.selectedFile);

      return axios
        .patch(`/components/${this.component.id}/apply_spreadsheet_update`, formData, {
          headers: { "Content-Type": "multipart/form-data" },
        })
        .then((response) => {
          this.updateResult = {
            success: true,
            message: response.data.toast || "Rules updated successfully.",
          };
          this.step = 5;
        })
        .catch((error) => {
          this.updateResult = {
            success: false,
            message:
              (error.response && error.response.data && error.response.data.error) ||
              "Update failed",
          };
          this.step = 5;
        });
    },
    onResultsClose() {
      if (this.updateResult && this.updateResult.success) {
        this.$emit("spreadsheet-updated");
      }
      this.$refs.modal.hide();
    },
    truncate(str) {
      if (!str) return "";
      const s = String(str);
      return s.length > 80 ? s.substring(0, 77) + "..." : s;
    },
    /**
     * Word-level diff: returns { old: [...segments], new: [...segments] }
     * Each segment: { text: string, changed: boolean }
     * Changed segments are highlighted; unchanged segments are dimmed context.
     */
    diffWords(oldStr, newStr) {
      const oldWords = String(oldStr || "").split(/(\s+)/);
      const newWords = String(newStr || "").split(/(\s+)/);

      // Build LCS table
      const m = oldWords.length;
      const n = newWords.length;
      const dp = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));
      for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
          dp[i][j] =
            oldWords[i - 1] === newWords[j - 1]
              ? dp[i - 1][j - 1] + 1
              : Math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }

      // Backtrack to find common tokens
      const oldFlags = new Array(m).fill(true); // true = changed
      const newFlags = new Array(n).fill(true);
      let i = m;
      let j = n;
      while (i > 0 && j > 0) {
        if (oldWords[i - 1] === newWords[j - 1]) {
          oldFlags[i - 1] = false;
          newFlags[j - 1] = false;
          i--;
          j--;
        } else if (dp[i - 1][j] > dp[i][j - 1]) {
          i--;
        } else {
          j--;
        }
      }

      // Build segments by merging consecutive same-flag tokens
      const buildSegments = (words, flags) => {
        const segs = [];
        for (let k = 0; k < words.length; k++) {
          const last = segs[segs.length - 1];
          if (last && last.changed === flags[k]) {
            last.text += words[k];
          } else {
            segs.push({ text: words[k], changed: flags[k] });
          }
        }
        return segs;
      };

      return {
        old: buildSegments(oldWords, oldFlags),
        new: buildSegments(newWords, newFlags),
      };
    },
  },
};
</script>

<style scoped>
.diff-old {
  background-color: #f8d7da;
  white-space: pre-wrap;
  word-break: break-word;
}
.diff-new {
  background-color: #d4edda;
  white-space: pre-wrap;
  word-break: break-word;
}
.diff-prefix {
  font-weight: bold;
  user-select: none;
}
.diff-highlight-old {
  background-color: #f5c6cb;
  font-weight: bold;
  border-radius: 2px;
  padding: 0 1px;
}
.diff-highlight-new {
  background-color: #a3cfbb;
  font-weight: bold;
  border-radius: 2px;
  padding: 0 1px;
}
.preview-scroll {
  max-height: 60vh;
  overflow-y: auto;
}
</style>
