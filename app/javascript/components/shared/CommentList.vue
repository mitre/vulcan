<script>
import { useCommentsStore } from "../../stores/comments";

export default {
  name: "CommentList",
  props: {
    componentId: { type: [Number, String], required: true },
    filterStatus: { type: String, default: "all" },
    filterSection: { type: String, default: null },
    highlightSection: { type: String, default: null },
    perPage: { type: Number, default: 25 },
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
      const params = { per_page: this.perPage };
      if (this.filterStatus && this.filterStatus !== "all") {
        params.triage_status = this.filterStatus;
      }
      if (this.filterSection) {
        params.section = this.filterSection;
      }
      return params;
    },
    normalizedRows() {
      const store = useCommentsStore();
      return this.rows.map((row) => store.normalizeComment(row));
    },
  },
  watch: {
    filterStatus: "fetch",
    filterSection: "fetch",
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
      if (!this.highlightSection) return false;
      return row.section !== this.highlightSection;
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

    if (!this.loading && this.normalizedRows.length === 0 && this.$scopedSlots.empty) {
      return h("div", [this.$scopedSlots.empty({})]);
    }

    const itemSlot = this.$scopedSlots.item;
    if (!itemSlot) return h("div");

    const items = this.normalizedRows.map((comment, index) =>
      itemSlot({
        comment,
        index,
        dimmed: this.isDimmed(comment),
        raw: this.rows[index],
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

    return h("div", { class: "comment-list" }, [...items, footer].filter(Boolean));
  },
};
</script>
