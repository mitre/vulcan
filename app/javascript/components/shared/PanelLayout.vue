<template>
  <b-card no-body class="panel-layout overflow-hidden">
    <b-row no-gutters class="flex-grow-1 h-100">
      <b-col
        v-for="(panel, index) in panels"
        :key="panel.name"
        cols="12"
        class="panel-layout__panel d-flex flex-column h-100"
        :class="panelClasses(panel, index)"
        :style="panelStyle(panel)"
      >
        <div
          v-if="$slots[panel.name + '-header']"
          class="panel-layout__header px-3 py-2 border-bottom flex-shrink-0"
        >
          <slot :name="panel.name + '-header'" />
        </div>

        <div class="panel-layout__body flex-grow-1 overflow-auto p-3">
          <slot :name="panel.name" />
        </div>

        <div
          v-if="$slots[panel.name + '-footer']"
          class="panel-layout__footer px-3 py-2 border-top flex-shrink-0"
        >
          <slot :name="panel.name + '-footer'" />
        </div>
      </b-col>
    </b-row>
  </b-card>
</template>

<script>
const BG_TIER_MAP = {
  body: "var(--vulcan-body-bg)",
  secondary: "var(--vulcan-secondary-bg)",
  tertiary: "var(--vulcan-tertiary-bg)",
};

// A panel is sized by its ROLE, not by a share of a 12-column grid. A
// sidebar holds fixed-size content — an identifier of known maximum width,
// a status dot, an icon strip — so its requirement is intrinsic and it gets
// a bounded width from the design system. Everything else divides what is
// left. Sizing a shell sidebar as a viewport fraction is what forced the
// requirement list to shrink its own font to fit.
const SIZE_ROLES = ["sidebar", "fill"];

export default {
  name: "PanelLayout",
  props: {
    panels: {
      type: Array,
      required: true,
      validator(value) {
        return value.every(
          (p) =>
            p.name && SIZE_ROLES.includes(p.size) && Object.keys(BG_TIER_MAP).includes(p.bgTier),
        );
      },
    },
  },
  methods: {
    panelStyle(panel) {
      return { backgroundColor: BG_TIER_MAP[panel.bgTier] };
    },
    panelClasses(panel, index) {
      const classes = [`panel-layout__panel--${panel.size}`];
      if (index < this.panels.length - 1) {
        classes.push("panel-layout__panel--border-right");
      }
      return classes;
    },
  },
};
</script>

<style scoped>
/* Panels stack full width below lg (Bootstrap's col-12). From lg up the
   shell takes over: the sidebar gets the bounded design-system width and
   the remaining panels share what is left. This is the same mechanism
   Bootstrap uses for its own column classes — flex basis plus max-width —
   with a token instead of a percentage, so the width tracks the content's
   needs rather than the viewport's size. min-width: 0 lets a filling panel
   shrink below its content's intrinsic width, the standard flexbox fix for
   overflow in a scrolling pane. */
@media (min-width: 992px) {
  .panel-layout__panel--sidebar {
    flex: 0 0 var(--vulcan-shell-sidebar-width);
    max-width: var(--vulcan-shell-sidebar-width);
  }

  .panel-layout__panel--fill {
    flex: 1 1 0;
    min-width: 0;
    max-width: 100%;
  }
}

.panel-layout__panel--border-right {
  border-right: 1px solid var(--vulcan-border-color);
}

/* Hold the scroll gutter whether or not the body is currently overflowing,
   matching the page root. This does nothing where the browser draws overlay
   scrollbars, which take no width at all; where it counts is a classic
   scrollbar, which otherwise appears and disappears with the row count and
   moves the usable content width by its own thickness as the user filters.
   Reserving it makes that width constant, which is what lets the sidebar's
   measured width floor mean the same thing in every state. */
.panel-layout__body {
  scrollbar-gutter: stable;
}

.panel-layout__header {
  flex-shrink: 0;
}

.panel-layout__footer {
  flex-shrink: 0;
}
</style>
