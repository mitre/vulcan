<template>
  <b-modal
    id="component-search-modal"
    size="lg"
    centered
    hide-header
    hide-footer
    body-class="p-0"
    content-class="component-search-modal"
    @shown="onShown"
    @hidden="onModalHidden"
  >
    <div class="search-header">
      <b-icon icon="search" class="text-muted mr-2" />
      <input
        ref="searchInput"
        v-model="query"
        type="text"
        class="search-input"
        :placeholder="placeholder"
        @input="onInput"
        @keydown="onKeyDown"
      />
      <b-spinner v-if="loading" small class="text-muted" />
      <kbd v-else class="search-kbd">ESC</kbd>
    </div>

    <div class="search-results">
      <div v-if="results.length === 0 && !loading" class="search-empty">
        <template v-if="query && query.length >= 2">
          <b-icon icon="search" class="mr-1" />
          No results for "{{ query }}"
        </template>
        <template v-else-if="query && query.length < 2">
          Type at least 2 characters to search...
        </template>
        <template v-else> Start typing to search... </template>
      </div>

      <div
        v-for="(result, index) in results"
        :key="result.id"
        :class="['search-result-item', { active: index === highlightedIndex }]"
        @click="selectResult(result)"
        @mouseenter="highlightedIndex = index"
      >
        <div class="d-flex align-items-start w-100">
          <b-icon :icon="resultIcon" class="result-icon mt-1 mr-2" />
          <div class="flex-grow-1 overflow-hidden">
            <div class="result-label text-truncate">
              <Highlighter
                v-if="searchWords.length > 0"
                highlight-class-name="search-highlight"
                :search-words="searchWords"
                :auto-escape="true"
                :text-to-highlight="formatResultLabel(result)"
              />
              <template v-else>{{ formatResultLabel(result) }}</template>
              <span v-if="result.title" class="result-title ml-1">{{ result.title }}</span>
            </div>
            <div v-if="result.snippet" class="result-snippet">
              <Highlighter
                v-if="searchWords.length > 0"
                highlight-class-name="search-highlight"
                :search-words="searchWords"
                :auto-escape="true"
                :text-to-highlight="result.snippet"
              />
              <template v-else>{{ result.snippet }}</template>
            </div>
            <div class="result-meta text-muted">
              <template v-if="result.author_name">
                <b-icon icon="person" class="mr-1" />
                {{ result.author_name }}
                <template v-if="result.triage_status"> · {{ result.triage_status }} </template>
              </template>
              <template v-else>
                <template v-if="result.parent_display_name">
                  <b-icon icon="arrow-return-right" class="mr-1" />
                  child of {{ result.parent_display_name }}
                  ·
                </template>
                <span v-if="result.comment_count != null">
                  {{ result.comment_count }} comment{{ result.comment_count === 1 ? "" : "s" }}
                </span>
              </template>
            </div>
          </div>
          <span v-if="index === highlightedIndex" class="result-hint">
            <b-icon icon="arrow-return-left" />
          </span>
        </div>
      </div>
    </div>

    <div v-if="results.length > 0" class="search-footer">
      <div class="d-flex text-muted small">
        <span class="mr-3"><kbd>↑</kbd><kbd>↓</kbd> Navigate</span>
        <span class="mr-3"><kbd>↵</kbd> Select</span>
        <span><kbd>esc</kbd> Close</span>
      </div>
      <span class="text-muted small">{{ resultCount }}</span>
    </div>
  </b-modal>
</template>

<script>
import _ from "lodash";
import axios from "axios";
import Highlighter from "vue-highlight-words";

export default {
  name: "ComponentSearchModal",
  components: { Highlighter },
  props: {
    componentId: { type: [Number, String], required: true },
    projectPrefix: { type: String, required: true },
    searchType: {
      type: String,
      default: "rules",
      validator: (v) => ["rules", "comments"].includes(v),
    },
  },
  data() {
    return {
      query: "",
      results: [],
      loading: false,
      highlightedIndex: -1,
    };
  },
  computed: {
    placeholder() {
      return this.searchType === "comments" ? "Search comments..." : "Search requirements...";
    },
    resultIcon() {
      return this.searchType === "comments" ? "chat-left-text" : "file-earmark-text";
    },
    resultCount() {
      const n = this.results.length;
      return `${n} result${n === 1 ? "" : "s"}`;
    },
    searchWords() {
      const term = (this.query || "").trim();
      if (!term) return [];
      return term.split(/\s+/).filter((w) => w.length >= 2);
    },
  },
  mounted() {
    this._onGlobalKeyDown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        this.$bvModal.show("component-search-modal");
      }
    };
    document.addEventListener("keydown", this._onGlobalKeyDown);
  },
  beforeDestroy() {
    if (this._onGlobalKeyDown) {
      document.removeEventListener("keydown", this._onGlobalKeyDown);
    }
  },
  methods: {
    onShown() {
      this.$nextTick(() => {
        if (this.$refs.searchInput) {
          this.$refs.searchInput.focus();
        }
      });
    },
    onModalHidden() {
      this.query = "";
      this.results = [];
      this.highlightedIndex = -1;
      this.loading = false;
      this.$emit("hidden");
    },
    onInput: _.debounce(function () {
      this.performSearch(this.query);
    }, 300),
    async performSearch(q) {
      const trimmed = (q || "").trim();
      if (trimmed.length < 2) {
        this.results = [];
        this.loading = false;
        return;
      }

      this.loading = true;
      try {
        if (this.searchType === "comments") {
          await this.searchComments(trimmed);
        } else {
          await this.searchRules(trimmed);
        }
        this.highlightedIndex = this.results.length > 0 ? 0 : -1;
      } catch (err) {
        this.results = [];
      } finally {
        this.loading = false;
      }
    },
    async searchRules(q) {
      const response = await axios.get("/api/search/global", {
        params: { q, limit: 20, component_id: this.componentId },
      });
      this.results = response.data.rules || [];
    },
    async searchComments(q) {
      const response = await axios.get(`/components/${this.componentId}/comments`, {
        params: { q, triage_status: "all", per_page: 20 },
      });
      this.results = (response.data.rows || []).map((row) => ({
        id: row.id,
        rule_id: row.rule_id,
        rule_displayed_name: row.rule_displayed_name,
        author_name: row.author_name,
        section: row.section,
        triage_status: row.triage_status,
        comment: row.comment,
        snippet: row.comment,
      }));
    },
    onKeyDown(event) {
      const { key } = event;
      if (key === "ArrowDown") {
        event.preventDefault();
        if (this.results.length === 0) return;
        this.highlightedIndex = (this.highlightedIndex + 1) % this.results.length;
      } else if (key === "ArrowUp") {
        event.preventDefault();
        if (this.results.length === 0) return;
        this.highlightedIndex =
          this.highlightedIndex <= 0 ? this.results.length - 1 : this.highlightedIndex - 1;
      } else if (key === "Enter") {
        event.preventDefault();
        if (this.highlightedIndex >= 0 && this.highlightedIndex < this.results.length) {
          this.selectResult(this.results[this.highlightedIndex]);
        }
      }
    },
    selectResult(result) {
      this.$emit("selected", { ...result, searchQuery: this.query });
      this.$bvModal.hide("component-search-modal");
    },
    formatResultLabel(result) {
      if (result.rule_displayed_name) return result.rule_displayed_name;
      const prefix = result.component_prefix || this.projectPrefix;
      return `${prefix}-${result.rule_id}`;
    },
  },
};
</script>

<style scoped>
.search-header {
  display: flex;
  align-items: center;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid #dee2e6;
}

.search-input {
  flex: 1;
  border: none;
  background: transparent;
  font-size: 1rem;
  outline: none;
}

.search-input::placeholder {
  color: #6c757d;
}

.search-kbd {
  padding: 0.125rem 0.375rem;
  font-size: 0.75rem;
  font-family: monospace;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.2rem;
  color: #6c757d;
}

.search-results {
  max-height: calc(70vh - 120px);
  overflow-y: auto;
  padding: 0.5rem;
}

.search-empty {
  padding: 2rem;
  text-align: center;
  color: #6c757d;
}

.search-result-item {
  display: flex;
  align-items: center;
  padding: 0.5rem 0.75rem;
  border-radius: 0.25rem;
  cursor: pointer;
  transition: background-color 0.1s;
}

.search-result-item:hover,
.search-result-item.active {
  background-color: #cce5ff; /* Bootstrap 4 $blue-100 / alert-primary bg */
}

.result-icon {
  color: #6c757d; /* $gray-600 */
  flex-shrink: 0;
}

.search-result-item.active .result-icon {
  color: #007bff; /* Bootstrap 4 $primary */
}

.result-label {
  font-weight: 500;
}

.result-title {
  font-weight: 400;
  font-size: 0.85rem;
  color: #6c757d;
}

.result-snippet {
  font-size: 0.8rem;
  color: #6c757d;
}

.search-highlight {
  background-color: #fff3cd;
  color: #856404;
  padding: 0 0.125rem;
  border-radius: 2px;
  font-weight: 600;
}

.result-meta {
  font-size: 0.75rem;
}

.result-hint {
  color: #6c757d;
  opacity: 0;
}

.search-result-item.active .result-hint {
  opacity: 1;
}

.search-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 1rem;
  border-top: 1px solid #dee2e6;
}

.search-footer kbd {
  padding: 0.1rem 0.3rem;
  font-size: 0.7rem;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.15rem;
  margin: 0 0.1rem;
}
</style>
