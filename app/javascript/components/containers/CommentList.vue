<script>
import { useCommentsStore } from "../../stores/comments";

export default {
  name: "CommentList",
  props: {
    componentId: { type: [Number, String], required: true },
    filterStatus: { type: String, default: "all" },
    filterSection: { type: String, default: null },
    filterRuleId: { type: [Number, String], default: null },
    commentableType: { type: String, default: null },
    highlightSection: { type: String, default: null },
    perPage: { type: Number, default: 25 },
    // Display cap: render at most this many rows while totals stay full.
    maxRows: { type: Number, default: null },
  },
  data() {
    return {
      rows: [],
      pagination: { page: 1, per_page: 25, total: 0 },
      statusCounts: {},
      loading: false,
      error: null,
    };
  },
  computed: {
    fetchParams() {
      // triage_status is ALWAYS explicit: the server defaults an omitted
      // value to "pending", which would silently hide triaged history.
      const params = { per_page: this.perPage, triage_status: this.filterStatus || "all" };
      if (this.filterSection) {
        params.section = this.filterSection;
      }
      if (this.filterRuleId != null) {
        params.rule_id = this.filterRuleId;
      }
      if (this.commentableType) {
        params.commentable_type = this.commentableType;
      }
      return params;
    },
    displayRows() {
      return this.maxRows != null ? this.rows.slice(0, this.maxRows) : this.rows;
    },
    totalComments() {
      return this.pagination.total_comments ?? this.pagination.total ?? 0;
    },
  },
  watch: {
    filterStatus: "fetch",
    filterSection: "fetch",
    filterRuleId: "fetch",
    commentableType: "fetch",
    componentId: "fetch",
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      this.error = null;
      try {
        const store = useCommentsStore();
        const data = await store.fetchComments(this.componentId, this.fetchParams);
        this.rows = data.rows || [];
        this.pagination = data.pagination || { page: 1, per_page: this.perPage, total: 0 };
        this.statusCounts = data.status_counts || {};
      } catch (err) {
        this.error = err;
        this.rows = [];
      } finally {
        this.loading = false;
      }
    },
    isDimmed(row) {
      // Dim only when it DISTINGUISHES: if no loaded row matches the
      // highlight section, an all-dimmed list reads as a disabled
      // overlay and communicates nothing.
      if (!this.highlightSection) return false;
      if (!this.rows.some((r) => r.section === this.highlightSection)) return false;
      return row.section !== this.highlightSection;
    },
    // Patch one loaded row in place (e.g. optimistic reaction updates).
    // Exposed to consumers through the item slot scope.
    updateRow(id, patch) {
      const idx = this.rows.findIndex((r) => r.id === id);
      if (idx < 0) return;
      this.$set(this.rows, idx, { ...this.rows[idx], ...patch });
    },
    refresh() {
      const store = useCommentsStore();
      store.invalidateCache(this.componentId);
      this.fetch();
    },
  },
  render(h) {
    if (this.loading && this.$scopedSlots.loading) {
      return h("div", [this.$scopedSlots.loading({})]);
    }

    if (this.error && this.$scopedSlots.error) {
      return h("div", [this.$scopedSlots.error({ error: this.error })]);
    }

    if (!this.loading && this.rows.length === 0 && this.$scopedSlots.empty) {
      return h("div", [this.$scopedSlots.empty({})]);
    }

    const itemSlot = this.$scopedSlots.item;
    if (!itemSlot) return h("div");

    const header =
      this.$scopedSlots.header &&
      this.$scopedSlots.header({
        rows: this.rows,
        total: this.pagination.total,
        totalComments: this.totalComments,
        statusCounts: this.statusCounts,
      });

    const items = this.displayRows.map((comment, index) =>
      itemSlot({
        comment,
        index,
        dimmed: this.isDimmed(comment),
        updateRow: this.updateRow,
      }),
    );

    const footer =
      this.$scopedSlots.footer &&
      this.$scopedSlots.footer({
        total: this.pagination.total,
        page: this.pagination.page,
        perPage: this.pagination.per_page,
        statusCounts: this.statusCounts,
      });

    return h("div", { class: "comment-list" }, [header, ...items, footer].filter(Boolean));
  },
};
</script>
