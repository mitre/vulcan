import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { createPinia, setActivePinia } from "pinia";
import { createTestRouter } from "@test/support/routerTestHelper";
import { useRuleSelectionStore } from "@/stores/ruleSelection";
import { commentsClosedTooltip } from "@/constants/triageVocabulary";
import RuleList from "@/components/rules/RuleList.vue";
import RuleRowIcons from "@/components/rules/RuleRowIcons.vue";

/**
 * RuleList requirements:
 *
 * 1. Renders "Open Rules" section with currently open rules from the store
 * 2. Renders "All Rules" section with the filtered rules passed as prop
 * 3. Clicking a rule row calls store.selectRule(rule.id)
 * 4. Clicking the X on an open rule calls store.deselectRule(rule.id)
 * 5. "close all" clears all open rules via store
 * 6. Highlights the selected rule row with .selectedRuleRow class
 * 7. Renders nesting tree when nestSatisfiedRulesChecked is true
 * 8. Shows comment badge icon for rules with open comments > 0
 * 9. Shows lock, review, changes-requested icons as appropriate
 * 10. Renders NewRuleModalForm when not readOnly
 */
describe("RuleList", () => {
  let wrapper;

  const createRule = (id, ruleId, overrides = {}) => ({
    id,
    rule_id: ruleId,
    version: `SV-${id}`,
    srg_id: `SRG-OS-${String(id).padStart(6, "0")}-GPOS-${String(id).padStart(5, "0")}`,
    status: "Applicable - Configurable",
    satisfies: [],
    satisfied_by: [],
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    histories: [],
    checks_attributes: [],
    disa_rule_descriptions_attributes: [],
    comment_summary: null,
    ...overrides,
  });

  const createSatisfactionRef = (id, ruleId, srgId) => ({
    id,
    rule_id: ruleId,
    srg_id: srgId,
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
  });

  const defaultProps = {
    filteredRules: [],
    allRules: [],
    componentId: 41,
    projectPrefix: "TEST",
    readOnly: false,
    nestSatisfiedRulesChecked: false,
    showSRGIdChecked: false,
  };

  let pinia;
  let router;

  const createWrapper = (props = {}, extraStubs = {}) => {
    pinia = createPinia();
    setActivePinia(pinia);
    router = createTestRouter([
      { path: "/", name: "editor-root" },
      { path: "/rules/:ruleId", name: "rule", props: true },
    ]);
    const store = useRuleSelectionStore();
    store.init(router, props.componentId || defaultProps.componentId);

    return shallowMount(RuleList, {
      localVue,
      pinia,
      router,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BIcon: true,
        BBadge: true,
        NewRuleModalForm: true,
        // Slot-inert named stub: the real container invokes its scoped
        // slots with live rows; the auto-stub would invoke them with an
        // empty scope and trip CommentItem's required-prop check (the
        // zero-stderr contract). Props declared so tests can assert them.
        CommentList: {
          name: "CommentList",
          props: ["componentId", "filterRuleId", "commentableType", "filterStatus"],
          render(h) {
            return h("div");
          },
        },
        ...extraStubs,
      },
      mocks: {
        $root: { $emit: () => {} },
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("open rules section", () => {
    it("renders open rules from the store", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      const store = useRuleSelectionStore();
      store.openRuleIds = [1];

      expect(wrapper.vm.openRules.length).toBe(1);
      expect(wrapper.vm.openRules[0].id).toBe(1);
    });

    it("shows 'close all' when open rules exist", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      const store = useRuleSelectionStore();
      store.openRuleIds = [1];

      // Force reactivity
      wrapper.vm.$forceUpdate();
      const closeAll = wrapper.find('[data-test="close-all-rules"]');
      // The close-all link should exist when there are open rules
      expect(store.openRuleIds.length).toBe(1);
    });
  });

  describe("rule selection", () => {
    it("calls store.selectRule when a rule row is clicked", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      wrapper.vm.ruleSelected(rules[0]);
      const store = useRuleSelectionStore();
      expect(store.selectedRuleId).toBe(1);
    });

    it("applies selectedRuleRow class to the currently selected rule", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      const store = useRuleSelectionStore();
      store.selectedRuleId = 1;

      const rowClass = wrapper.vm.ruleRowClass(rules[0]);
      expect(rowClass.selectedRuleRow).toBe(true);
    });

    it("does not apply selectedRuleRow class to non-selected rules", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      const store = useRuleSelectionStore();
      store.selectedRuleId = 1;

      const rowClass = wrapper.vm.ruleRowClass(rules[1]);
      expect(rowClass.selectedRuleRow).toBe(false);
    });
  });

  describe("rule formatting", () => {
    it("formats rule ID with project prefix", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.formatRuleId("000001")).toBe("TEST-000001");
    });
  });

  describe("status dots", () => {
    it("renders a dot per row carrying data-status and an accessible name — stig vocabulary", () => {
      const rule = createRule(1, "000001", { status: "Applicable - Configurable" });
      wrapper = createWrapper({ allRules: [rule], filteredRules: [rule] });
      const dot = wrapper.find('[data-test="all-rules-header"] ~ div .status-dot');
      expect(dot.exists()).toBe(true);
      expect(dot.attributes("data-status")).toBe("Applicable - Configurable");
      expect(dot.attributes("aria-label")).toBe("Status: Applicable - Configurable");
      expect(dot.attributes("title")).toBe("Applicable - Configurable");
    });

    it("renders the dot for an authored-shaped srg row (no Rule-only keys)", () => {
      const authored = {
        id: 9,
        rule_id: "000009",
        version: "SRG-APP-000009",
        srg_id: "SRG-APP-000009",
        status: "Applicable",
        locked: false,
        review_requestor_id: null,
        changes_requested: false,
        comment_summary: null,
      };
      wrapper = createWrapper({ allRules: [authored], filteredRules: [authored] });
      const dot = wrapper.find(".status-dot");
      expect(dot.attributes("data-status")).toBe("Applicable");
      expect(dot.attributes("aria-label")).toBe("Status: Applicable");
    });

    it("resolves a nested satisfies row's status from allRules (refs carry no status)", async () => {
      const child = createRule(21, "000021", { status: "Not Applicable" });
      const childRef = createSatisfactionRef(21, "000021", "SRG-OS-000021");
      const parent = createRule(20, "000020", {
        status: "Applicable - Does Not Meet",
        satisfies: [childRef],
      });
      wrapper = createWrapper({
        allRules: [parent, child],
        filteredRules: [parent],
        nestSatisfiedRulesChecked: true,
      });
      wrapper.vm.toggleParentExpanded(parent.id);
      await wrapper.vm.$nextTick();
      const childDot = wrapper.find(".nested-children .status-dot");
      expect(childDot.exists()).toBe(true);
      expect(childDot.attributes("data-status")).toBe("Not Applicable");
    });
  });

  describe("comments modal", () => {
    // BModal auto-stub drops its slot; a render-function stub keeps the
    // default slot so the hosted CommentList is assertable (runtime-only
    // build — no template-string stubs).
    const modalSlotStub = {
      render(h) {
        return h("div", [this.$slots.default, this.$slots["modal-footer"]]);
      },
    };

    it("open-comments from a row icon shows the modal via the real $bvModal injection", async () => {
      const rule = createRule(3, "000003");
      wrapper = createWrapper({ allRules: [rule], filteredRules: [rule] });
      const show = vi.spyOn(wrapper.vm.$bvModal, "show");
      wrapper.findComponent({ name: "RuleRowIcons" }).vm.$emit("open-comments", rule);
      await wrapper.vm.$nextTick();
      expect(show).toHaveBeenCalledWith("rule-comments-modal");
      expect(wrapper.vm.commentsRule).toEqual(rule);
    });

    it("hosts CommentList filtered to the requirement, titled with the displayed id", async () => {
      const rule = createRule(3, "000003");
      wrapper = createWrapper(
        { allRules: [rule], filteredRules: [rule] },
        { BModal: modalSlotStub },
      );
      wrapper.findComponent({ name: "RuleRowIcons" }).vm.$emit("open-comments", rule);
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.commentsModalTitle).toBe("TEST-000003");
      const list = wrapper.findComponent({ name: "CommentList" });
      expect(list.exists()).toBe(true);
      expect(list.props("componentId")).toBe(41);
      expect(list.props("filterRuleId")).toBe(3);
    });

    it("footer Add Comment emits add-comment with the rule and hides the modal", async () => {
      const rule = createRule(3, "000003");
      wrapper = createWrapper(
        { allRules: [rule], filteredRules: [rule] },
        { BModal: modalSlotStub },
      );
      const hide = vi.spyOn(wrapper.vm.$bvModal, "hide");
      wrapper.vm.openComments(rule);
      await wrapper.vm.$nextTick();
      const btn = wrapper.find('[data-test="modal-add-comment"]');
      expect(btn.exists()).toBe(true);
      expect(btn.attributes("disabled")).toBeUndefined();
      await btn.trigger("click");
      expect(wrapper.emitted("add-comment")).toHaveLength(1);
      expect(wrapper.emitted("add-comment")[0][0]).toEqual(rule);
      expect(hide).toHaveBeenCalledWith("rule-comments-modal");
    });

    it("Add Comment is disabled-not-hidden when the comment phase is closed", async () => {
      const rule = createRule(3, "000003");
      wrapper = createWrapper(
        { allRules: [rule], filteredRules: [rule] },
        { BModal: modalSlotStub },
      );
      // Re-mount with the tree-scoped gate the pages provide.
      wrapper.destroy();
      wrapper = shallowMount(RuleList, {
        localVue,
        pinia,
        router,
        propsData: { ...defaultProps, allRules: [rule], filteredRules: [rule] },
        provide: { isCommentsClosed: () => true, getClosedReason: () => "archived" },
        stubs: {
          BIcon: true,
          BBadge: true,
          NewRuleModalForm: true,
          BModal: modalSlotStub,
          CommentList: {
            name: "CommentList",
            props: ["componentId", "filterRuleId"],
            render(h) {
              return h("div");
            },
          },
        },
      });
      wrapper.vm.openComments(rule);
      await wrapper.vm.$nextTick();
      const btn = wrapper.find('[data-test="modal-add-comment"]');
      expect(btn.exists()).toBe(true);
      expect(btn.attributes("disabled")).toBeTruthy();
      expect(wrapper.vm.addCommentTooltip).toBe(commentsClosedTooltip("archived"));
    });

    it("Add Comment is disabled when the requirement is locked, with the locked tooltip", async () => {
      const rule = createRule(3, "000003", { locked: true });
      wrapper = createWrapper(
        { allRules: [rule], filteredRules: [rule] },
        { BModal: modalSlotStub },
      );
      wrapper.vm.openComments(rule);
      await wrapper.vm.$nextTick();
      const btn = wrapper.find('[data-test="modal-add-comment"]');
      expect(btn.attributes("disabled")).toBeTruthy();
      expect(wrapper.vm.addCommentTooltip).toBe(
        "Rule is locked — comments are closed for this rule",
      );
    });

    it("a reply from a hosted comment emits reply-comment with the ROW even though the inner chain emits an id", async () => {
      // The real CommentThread → CommentActions → CommentItem chain emits
      // the parent review ID (a number), NOT the row — the item slot must
      // bind the slot-scoped comment, exactly like the comments table does.
      const commentRow = {
        id: 77,
        rule_id: 3,
        component_id: 41,
        rule_displayed_name: "TEST-000003",
      };
      const itemRenderingListStub = {
        name: "CommentList",
        render(h) {
          const item =
            this.$scopedSlots.item &&
            this.$scopedSlots.item({ comment: commentRow, dimmed: false, updateRow: () => {} });
          return h("div", [item]);
        },
      };
      const rule = createRule(3, "000003");
      wrapper = createWrapper(
        { allRules: [rule], filteredRules: [rule] },
        { BModal: modalSlotStub, CommentList: itemRenderingListStub },
      );
      const hide = vi.spyOn(wrapper.vm.$bvModal, "hide");
      wrapper.vm.openComments(rule);
      await wrapper.vm.$nextTick();
      const item = wrapper.findComponent({ name: "CommentItem" });
      expect(item.exists()).toBe(true);
      item.vm.$emit("reply", 999);
      expect(wrapper.emitted("reply-comment")).toHaveLength(1);
      expect(wrapper.emitted("reply-comment")[0][0]).toEqual(commentRow);
      expect(hide).toHaveBeenCalledWith("rule-comments-modal");
    });

    it("all three row variants forward open-comments (open rules, all rules, children)", async () => {
      const child = createRule(21, "000021");
      const parent = createRule(20, "000020", { satisfies: [child] });
      wrapper = createWrapper({
        allRules: [parent, child],
        filteredRules: [parent],
        nestSatisfiedRulesChecked: true,
      });
      wrapper.vm.ruleStore.openRuleIds = [parent.id];
      wrapper.vm.toggleParentExpanded(parent.id);
      await wrapper.vm.$nextTick();
      const icons = wrapper.findAllComponents({ name: "RuleRowIcons" });
      expect(icons.length).toBe(3);
      for (let i = 0; i < icons.length; i += 1) {
        wrapper.vm.commentsRule = null;
        icons.at(i).vm.$emit("open-comments", i === 2 ? child : parent);
        await wrapper.vm.$nextTick();
        expect(wrapper.vm.commentsRule).not.toBeNull();
      }
    });
  });

  describe("identifier is never silently truncated", () => {
    // REQUIREMENT: the sidebar label is nowrap + ellipsis, so an identifier
    // that ever exceeds the sidebar's width is clipped visually. The full
    // value must therefore ALWAYS be recoverable on hover — in BOTH display
    // modes, not only when SRG IDs are shown. The rule_id mode is the
    // default and is the one STIG components use, so it is the mode that
    // matters most; it previously had no title at all.
    // .rule-row-label IS the identifier span — the only element that
    // truncates — so its title is what must carry the full value.
    const idSpanTitle = (w, text) => {
      const span = w.findAll(".rule-row-label").wrappers.find((s) => s.text().trim() === text);
      return span ? span.attributes("title") : undefined;
    };

    it("carries the full identifier in a title in rule_id display mode", () => {
      const rule = createRule(1, "000020");
      wrapper = createWrapper({
        filteredRules: [rule],
        allRules: [rule],
        showSRGIdChecked: false,
        projectPrefix: "CNTR-00",
      });
      expect(idSpanTitle(wrapper, "CNTR-00-000020")).toBe("CNTR-00-000020");
    });

    it("carries the full, untruncated identifier in a title in SRG ID mode", () => {
      const rule = createRule(2, "000021");
      wrapper = createWrapper({
        filteredRules: [rule],
        allRules: [rule],
        showSRGIdChecked: true,
        projectPrefix: "CNTR-00",
      });
      // The displayed text is truncated; the title must carry the whole id.
      expect(idSpanTitle(wrapper, "SRG-OS-000002")).toBe(rule.srg_id);
    });

    it("keeps the child-count badge outside the truncating label", () => {
      // The badge is secondary but must never be eaten by the identifier's
      // ellipsis, so it lives beside the label rather than inside it.
      const child = createSatisfactionRef(9, "000099", "SRG-OS-000009");
      const parent = createRule(3, "000030", { satisfies: [child] });
      wrapper = createWrapper({
        filteredRules: [parent],
        allRules: [parent, createRule(9, "000099")],
        nestSatisfiedRulesChecked: true,
      });
      const badge = wrapper.find(".child-count");
      expect(badge.exists()).toBe(true);
      expect(badge.element.closest(".rule-row-label")).toBeNull();
    });
  });

  describe("row icon strip is never squeezed", () => {
    // REQUIREMENT: the trailing icon strip has an intrinsic width. If the
    // label group is allowed to squeeze it, its icons wrap onto a second
    // line and the whole row doubles in height — which is what happened at
    // the lg breakpoint with nesting on. The strip must not shrink; the
    // identifier absorbs any shortfall instead (it ellipsizes with a
    // tooltip carrying the full value).
    it("marks the icon strip non-shrinking on every row site", () => {
      const child = createSatisfactionRef(21, "000021", "SRG-OS-000021");
      const parent = createRule(20, "000020", { satisfies: [child] });
      const leaf = createRule(21, "000021");
      wrapper = createWrapper({
        filteredRules: [parent, leaf],
        allRules: [parent, leaf],
        nestSatisfiedRulesChecked: true,
      });

      const strips = wrapper.findAllComponents(RuleRowIcons);
      expect(strips.length).toBeGreaterThan(0);
      strips.wrappers.forEach((strip) => {
        expect(strip.classes()).toContain("flex-shrink-0");
      });
    });
  });

  describe("SRG ID display toggle", () => {
    // Authored SRG rows omit Rule-only keys entirely (satisfies,
    // satisfied_by, checks_attributes, disa_rule_descriptions_attributes)
    // — fixtures must mirror that authentic shape, not pass [].
    const authoredRow = {
      id: 901,
      rule_id: "000002",
      version: "SRG-APP-000003",
      srg_id: "SRG-APP-000003",
      status: "Applicable",
      locked: false,
      review_requestor_id: null,
      changes_requested: false,
      comment_summary: null,
    };

    it("renders the requirement identifier for an authored-shaped row when the toggle is on", () => {
      wrapper = createWrapper({
        allRules: [authoredRow],
        filteredRules: [authoredRow],
        showSRGIdChecked: true,
      });
      expect(wrapper.text()).toContain("SRG-APP-000003");
      expect(wrapper.text()).not.toContain("000002");
    });

    it("renders the truncated srg_id for a STIG-shaped row when the toggle is on", () => {
      const stigRow = createRule(7, "STIG-00-000007");
      wrapper = createWrapper({
        allRules: [stigRow],
        filteredRules: [stigRow],
        showSRGIdChecked: true,
      });
      expect(wrapper.text()).toContain("SRG-OS-000007");
      expect(wrapper.text()).not.toContain("GPOS");
    });

    it("falls back to the formatted rule ID when the toggle is off", () => {
      wrapper = createWrapper({
        allRules: [authoredRow],
        filteredRules: [authoredRow],
        showSRGIdChecked: false,
      });
      expect(wrapper.text()).toContain("000002");
    });
  });

  describe("comment count rollup", () => {
    it("returns parent's own count plus all children's open counts", () => {
      const child1 = createRule(10, "001002", { comment_summary: { open: 2, total: 3 } });
      const child2 = createRule(11, "001003", { comment_summary: { open: 1, total: 2 } });
      const parent = createRule(1, "000020", {
        comment_summary: { open: 1, total: 5 },
        satisfies: [
          createSatisfactionRef(10, "001002", "SRG-OS-000010"),
          createSatisfactionRef(11, "001003", "SRG-OS-000011"),
        ],
      });

      wrapper = createWrapper({ filteredRules: [parent], allRules: [parent, child1, child2] });
      expect(wrapper.vm.ruleOpen(parent)).toBe(4);
    });

    it("returns 0 for rules with no comment_summary", () => {
      const rule = createRule(1, "000001");
      wrapper = createWrapper({ filteredRules: [rule], allRules: [rule] });
      expect(wrapper.vm.ruleOpen(rule)).toBe(0);
    });
  });

  describe("nesting", () => {
    it("hasParentRules is true when a filtered rule has satisfies", () => {
      const parent = createRule(1, "000001", {
        satisfies: [createSatisfactionRef(2, "000002", "SRG-OS-000002")],
      });
      wrapper = createWrapper({ filteredRules: [parent], allRules: [parent] });
      expect(wrapper.vm.hasParentRules).toBe(true);
    });

    it("hasParentRules is false when no filtered rules have satisfies", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      expect(wrapper.vm.hasParentRules).toBe(false);
    });

    it("toggleParentExpanded toggles a parent's expanded state", () => {
      const parent = createRule(1, "000001", {
        satisfies: [createSatisfactionRef(2, "000002", "SRG-OS-000002")],
      });
      wrapper = createWrapper({ filteredRules: [parent], allRules: [parent] });

      expect(wrapper.vm.isParentExpanded(1)).toBe(false);
      wrapper.vm.toggleParentExpanded(1);
      expect(wrapper.vm.isParentExpanded(1)).toBe(true);
      wrapper.vm.toggleParentExpanded(1);
      expect(wrapper.vm.isParentExpanded(1)).toBe(false);
    });

    it("sortAlsoSatisfies sorts by rule_id", () => {
      const refs = [
        createSatisfactionRef(10, "001003", "SRG-OS-000010"),
        createSatisfactionRef(11, "001002", "SRG-OS-000011"),
      ];
      wrapper = createWrapper();
      const sorted = wrapper.vm.sortAlsoSatisfies(refs);
      expect(sorted[0].rule_id).toBe("001002");
      expect(sorted[1].rule_id).toBe("001003");
    });
  });

  describe("readOnly mode", () => {
    it("does not render add button when readOnly is true", () => {
      wrapper = createWrapper({ readOnly: true, filteredRules: [] });
      const addBtn = wrapper.find('[data-test="add-rule-btn"]');
      expect(addBtn.exists()).toBe(false);
    });
  });

  describe("count indicator", () => {
    it("shows total count when no filter is active", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002"), createRule(3, "000003")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules, hasActiveFilters: false });
      const header = wrapper.find('[data-test="all-rules-header"]');
      expect(header.text()).toContain("(3)");
      expect(header.text()).not.toContain("of");
    });

    it("shows 'X of Y' when filter is active", () => {
      const allRules = [createRule(1, "000001"), createRule(2, "000002"), createRule(3, "000003")];
      const filteredRules = [allRules[0]];
      wrapper = createWrapper({ filteredRules, allRules, hasActiveFilters: true });
      const header = wrapper.find('[data-test="all-rules-header"]');
      expect(header.text()).toContain("1 of 3");
    });

    it("shows 'reset' link when filter is active", () => {
      const allRules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: [allRules[0]], allRules, hasActiveFilters: true });
      const reset = wrapper.find('[data-test="inline-clear-filters"]');
      expect(reset.exists()).toBe(true);
    });

    it("does not show 'reset' link when no filter is active", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules, hasActiveFilters: false });
      const reset = wrapper.find('[data-test="inline-clear-filters"]');
      expect(reset.exists()).toBe(false);
    });

    it("does not show 'reset' when only nesting reduces count (not a filter)", () => {
      const allRules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: [allRules[0]], allRules, hasActiveFilters: false });
      const reset = wrapper.find('[data-test="inline-clear-filters"]');
      expect(reset.exists()).toBe(false);
      const header = wrapper.find('[data-test="all-rules-header"]');
      expect(header.text()).toContain("(2)");
      expect(header.text()).not.toContain("of");
    });

    it("emits reset-filters when inline reset is clicked", () => {
      const allRules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: [allRules[0]], allRules, hasActiveFilters: true });
      wrapper.find('[data-test="inline-clear-filters"]').trigger("click");
      expect(wrapper.emitted("reset-filters")).toBeTruthy();
    });
  });

  describe("SRG ID display", () => {
    const srgIdParent = "SRG-OS-000001-GPOS-00001";
    const srgIdChild1 = "SRG-OS-000480-GPOS-00227";
    const srgIdChild2 = "SRG-APP-000123-GPOS-00456";

    const createParentWithChildren = () => {
      const child1 = createSatisfactionRef(10, "001002", srgIdChild1);
      const child2 = createSatisfactionRef(11, "001003", srgIdChild2);
      const parentRule = createRule(1, "000020", {
        version: srgIdParent,
        srg_id: srgIdParent,
        satisfies: [child1, child2],
      });
      return { parentRule, child1, child2 };
    };

    it("ALWAYS displays SRG IDs for nested children regardless of toggle", () => {
      const { parentRule } = createParentWithChildren();
      wrapper = createWrapper({
        filteredRules: [parentRule],
        allRules: [parentRule],
        nestSatisfiedRulesChecked: true,
        showSRGIdChecked: false,
      });
      wrapper.setData({ expandedParents: new Set([parentRule.id]) });

      const childRows = wrapper.findAll(".child-row");
      expect(childRows.length).toBe(2);

      const child1Text = childRows.at(0).text();
      expect(child1Text).toContain("SRG-OS-000480");
      const child2Text = childRows.at(1).text();
      expect(child2Text).toContain("SRG-APP-000123");
    });

    it("shows full SRG ID in tooltip for nested children", () => {
      const { parentRule } = createParentWithChildren();
      wrapper = createWrapper({
        filteredRules: [parentRule],
        allRules: [parentRule],
        nestSatisfiedRulesChecked: true,
        showSRGIdChecked: false,
      });
      wrapper.setData({ expandedParents: new Set([parentRule.id]) });

      const childRows = wrapper.findAll(".child-row");
      // The status dot also carries a title — exclude it; this test is
      // about the SRG id tooltip.
      const tooltipSpans = childRows.at(0).findAll("span[title]:not(.status-dot)");
      expect(tooltipSpans.length).toBeGreaterThan(0);
      const titleValue = tooltipSpans.at(0).attributes("title");
      expect(titleValue).toBeTruthy();
      expect(titleValue).toMatch(/^SRG-/);
    });

    it("displays truncated SRG ID for parent when showSRGIdChecked is true", () => {
      const { parentRule } = createParentWithChildren();
      wrapper = createWrapper({
        filteredRules: [parentRule],
        allRules: [parentRule],
        nestSatisfiedRulesChecked: true,
        showSRGIdChecked: true,
      });

      const allRows = wrapper.findAll(".ruleRow");
      expect(allRows.length).toBeGreaterThan(0);
      const parentText = allRows.at(0).text();
      expect(parentText).toContain("SRG-OS-000001");

      const tooltipSpan = allRows.at(0).find("span[title]:not(.status-dot)");
      expect(tooltipSpan.exists()).toBe(true);
      expect(tooltipSpan.attributes("title")).toBe(srgIdParent);
    });

    it("displays formatted rule ID when showSRGIdChecked is false", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({
        filteredRules: rules,
        allRules: rules,
        showSRGIdChecked: false,
      });

      const row = wrapper.find(".ruleRow");
      expect(row.text()).toContain("TEST-000001");
    });
  });

  // ── Authored-row tolerance (SRG kind — leak/robustness regression) ──
  describe("authored SRG rows (no Rule-only payload keys)", () => {
    it("renders rows that omit satisfies/satisfied_by entirely, with nesting enabled", () => {
      // Authentic authored-row shape: kind-shaped payloads omit the
      // Rule-only association keys rather than sending empty arrays.
      const authoredRow = {
        id: 71,
        rule_id: "000010",
        version: "SRG-OS-000001",
        status: "Applicable",
        locked: false,
        review_requestor_id: null,
        changes_requested: false,
        comment_summary: null,
      };
      wrapper = createWrapper({
        filteredRules: [authoredRow],
        allRules: [authoredRow],
        nestSatisfiedRulesChecked: true,
      });
      const row = wrapper.find(".ruleRow");
      expect(row.exists()).toBe(true);
      expect(row.text()).toContain("TEST-000010");
    });
  });

  describe("relocation marker pass-through", () => {
    it("hands each row its pending relocation from the markers map", () => {
      const rule = createRule(7, "000007");
      wrapper = createWrapper({
        allRules: [rule],
        filteredRules: [rule],
        pendingRelocations: { 7: { id: 99, target_technology_token: "CTR" } },
      });

      const icons = wrapper.findAllComponents(RuleRowIcons);
      const withMarker = icons.wrappers.find(
        (w) => w.props("pendingRelocation") && w.props("pendingRelocation").id === 99,
      );
      expect(withMarker).toBeDefined();
      expect(withMarker.props("pendingRelocation").target_technology_token).toBe("CTR");
    });
  });
});
