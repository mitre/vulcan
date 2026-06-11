<script>
// Mixin that allows re-use of the display function for components.
// Superseded by composables/useDisplayedComponent.js (kept in lockstep
// until the mixins/ directory is removed in v2-0re.10).
export default {
  methods: {
    // Display component version and release if present:
    // "Name (Version X, Release Y)" with only the parts that exist.
    addDisplayNameToComponents: function (components) {
      return components.map((component) => {
        const parts = [
          component.version ? `Version ${component.version}` : null,
          component.release ? `Release ${component.release}` : null,
        ].filter(Boolean);
        component.displayed = parts.length
          ? `${component.name} (${parts.join(", ")})`
          : component.name;
        return component;
      });
    },
  },
};
</script>
