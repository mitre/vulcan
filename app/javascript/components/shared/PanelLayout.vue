<template>
  <b-row no-gutters class="panel-layout">
    <b-col
      v-for="(panel, index) in panels"
      :key="panel.name"
      :lg="panel.cols"
      cols="12"
      class="panel-layout__panel d-flex flex-column"
      :class="panelClasses(panel, index)"
      :style="panelStyle(panel)"
    >
      <div
        v-if="$slots[panel.name + '-header']"
        class="panel-layout__header px-3 py-2 border-bottom"
      >
        <slot :name="panel.name + '-header'" />
      </div>

      <div class="panel-layout__body flex-grow-1 overflow-auto min-height-0 p-3">
        <slot :name="panel.name" />
      </div>

      <div v-if="$slots[panel.name + '-footer']" class="panel-layout__footer px-3 py-2 border-top">
        <slot :name="panel.name + '-footer'" />
      </div>
    </b-col>
  </b-row>
</template>

<script>
const BG_TIER_MAP = {
  body: "var(--vulcan-body-bg)",
  secondary: "var(--vulcan-secondary-bg)",
  tertiary: "var(--vulcan-tertiary-bg)",
};

export default {
  name: "PanelLayout",
  props: {
    panels: {
      type: Array,
      required: true,
      validator(value) {
        return value.every((p) => p.name && p.cols && Object.keys(BG_TIER_MAP).includes(p.bgTier));
      },
    },
  },
  methods: {
    panelStyle(panel) {
      return { backgroundColor: BG_TIER_MAP[panel.bgTier] };
    },
    panelClasses(panel, index) {
      const classes = [`col-lg-${panel.cols}`];
      if (index < this.panels.length - 1) {
        classes.push("panel-layout__panel--border-right");
      }
      return classes;
    },
  },
};
</script>

<style scoped>
.panel-layout__panel--border-right {
  border-right: 1px solid var(--vulcan-border-color);
}

.panel-layout__header {
  flex-shrink: 0;
}

.panel-layout__footer {
  flex-shrink: 0;
}
</style>
