<template>
  <b-form-group v-if="shouldDisplay" :id="groupId" :class="[extraClass, stateClass]">
    <!-- Label with tooltip + lock icons (skip for checkbox mode) -->
    <label v-if="!checkboxMode" :for="inputId">
      {{ label }}
      <b-icon
        v-if="tooltipText"
        v-b-tooltip.hover.html="tooltipText"
        icon="info-circle"
        aria-hidden="true"
      />
      <b-icon
        v-if="showSectionLockIcon && isSectionLocked"
        v-b-tooltip.hover="
          canManageSectionLocks
            ? 'Click to unlock ' + resolvedSection + ' section'
            : 'Section locked (set status to manage locks)'
        "
        icon="lock-fill"
        :class="['ml-1', canManageSectionLocks ? 'text-warning clickable' : 'text-muted']"
        :data-testid="'section-lock-' + resolvedSection.replace(/\s+/g, '')"
        @click="canManageSectionLocks && $emit('toggle-section-lock', resolvedSection)"
      />
      <b-icon
        v-else-if="showSectionLockIcon && !isSectionLocked"
        v-b-tooltip.hover="
          canManageSectionLocks
            ? 'Click to lock ' + resolvedSection + ' section'
            : 'Set status to manage section locks'
        "
        icon="unlock"
        :class="[
          'ml-1',
          canManageSectionLocks ? 'text-success clickable' : 'text-muted opacity-50',
        ]"
        :data-testid="'section-lock-' + resolvedSection.replace(/\s+/g, '')"
        @click="canManageSectionLocks && $emit('toggle-section-lock', resolvedSection)"
      />
      <SectionCommentIcon
        v-if="showCommentIcon && xccdfSection"
        :section="xccdfSection"
        :open-count="openCommentCount"
        :locked="ruleLocked"
        :comments-closed="commentsClosedInjected"
        :closed-reason="closedReasonInjected"
        class="ml-1"
        @open-composer="$emit('open-composer', xccdfSection)"
      />
    </label>

    <!-- Input slot — parent provides the actual input element -->
    <slot :input-id="inputId" :is-disabled="computedDisabled" />

    <!-- Feedback (skip for checkbox/readonly) -->
    <template v-if="!checkboxMode && !readOnly">
      <b-form-valid-feedback v-if="hasValidFeedback">
        {{ validFeedback[fieldName] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback">
        {{ invalidFeedback[fieldName] }}
      </b-form-invalid-feedback>
    </template>
  </b-form-group>
</template>

<script>
import { FIELD_TO_SECTION } from "../../composables/ruleFieldConfig";
import { DISPLAY_TO_XCCDF_SECTION } from "../../constants/triageVocabulary";
import SectionCommentIcon from "./SectionCommentIcon.vue";

let _rfgUid = 0;

export default {
  name: "RuleFormGroup",
  components: { SectionCommentIcon },
  // Inject the parent's commentsClosed signal so the section comment icon
  // can disable when the public-comment window isn't open. Default keeps
  // tests + isolated mounts green.
  inject: {
    isCommentsClosed: { default: () => () => false },
    getClosedReason: { default: () => () => null },
  },
  props: {
    fieldName: { type: String, required: true },
    label: { type: String, required: true },
    fields: { type: Object, required: true },
    fieldStateClassFn: { type: Function, default: () => () => "" },
    tooltip: { type: String, default: null },
    disabled: { type: Boolean, default: false },
    lockedSections: { type: Object, default: () => ({}) },
    canManageSectionLocks: { type: Boolean, default: false },
    showSectionLocks: { type: Boolean, default: false },
    lockSection: { type: String, default: null },
    validFeedback: { type: Object, default: () => ({}) },
    invalidFeedback: { type: Object, default: () => ({}) },
    checkboxMode: { type: Boolean, default: false },
    readOnly: { type: Boolean, default: false },
    extraClass: { type: [String, Array, Object], default: "" },
    idPrefix: { type: String, default: "ruleEditor" },
    customDisplayCheck: { type: Function, default: null },
    // Section comment icon. Default false so existing call sites
    // are unaffected; consumers opt in for the first field of each section.
    showCommentIcon: { type: Boolean, default: false },
    ruleReviews: { type: Array, default: () => [] },
    ruleLocked: { type: Boolean, default: false },
  },
  data() {
    return { mod: _rfgUid++ };
  },
  computed: {
    groupId() {
      return `${this.idPrefix}-${this.fieldName}-group-${this.mod}`;
    },
    inputId() {
      return `${this.idPrefix}-${this.fieldName}-${this.mod}`;
    },
    shouldDisplay() {
      if (this.customDisplayCheck) return this.customDisplayCheck();
      return this.fields.displayed.includes(this.fieldName);
    },
    computedDisabled() {
      return this.disabled || this.fields.disabled.includes(this.fieldName);
    },
    stateClass() {
      return this.fieldStateClassFn(this.fieldName);
    },
    tooltipText() {
      return this.tooltip;
    },
    // Auto-resolve section from FIELD_TO_SECTION lookup, with manual override via lockSection prop
    resolvedSection() {
      return this.lockSection || FIELD_TO_SECTION[this.fieldName] || null;
    },
    showSectionLockIcon() {
      return (this.showSectionLocks || this.canManageSectionLocks) && !!this.resolvedSection;
    },
    isSectionLocked() {
      return !!(
        this.resolvedSection &&
        this.lockedSections &&
        this.lockedSections[this.resolvedSection]
      );
    },
    hasValidFeedback() {
      return !!(this.validFeedback && this.validFeedback[this.fieldName]);
    },
    hasInvalidFeedback() {
      return !!(this.invalidFeedback && this.invalidFeedback[this.fieldName]);
    },
    // resolvedSection returns the friendly display label ("Check"); the
    // comments API expects the XCCDF key ("check_content").
    xccdfSection() {
      return this.resolvedSection ? DISPLAY_TO_XCCDF_SECTION[this.resolvedSection] || null : null;
    },
    // Open comments scoped to this section — non-adjudicated top-level
    // comments (pending OR triaged-but-not-yet-closed OR needs_clarification)
    // plus any replies whose parent is in that open set. Replies inherit
    // the parent's section semantically (server stores null on the reply
    // row). Once the parent is adjudicated, both it and its replies leave
    // the count.
    openCommentCount() {
      if (!this.xccdfSection || !this.ruleReviews || this.ruleReviews.length === 0) return 0;
      const topLevelOnSection = this.ruleReviews.filter(
        (r) =>
          r.action === "comment" &&
          r.responding_to_review_id == null &&
          r.adjudicated_at == null &&
          r.section === this.xccdfSection,
      );
      if (topLevelOnSection.length === 0) return 0;
      const parentIds = new Set(topLevelOnSection.map((r) => r.id));
      const replies = this.ruleReviews.filter(
        (r) => r.responding_to_review_id != null && parentIds.has(r.responding_to_review_id),
      );
      return topLevelOnSection.length + replies.length;
    },
    commentsClosedInjected() {
      return this.isCommentsClosed();
    },
    closedReasonInjected() {
      return this.getClosedReason();
    },
  },
};
</script>
