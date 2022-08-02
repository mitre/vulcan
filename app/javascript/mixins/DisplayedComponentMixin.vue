<script>
// Mixin that allows re-use of the display function for components
export default {
  methods: {
    // Display component version and release if present
    addDisplayNameToComponents: function (components) {
      return components.map((component) => {
        component.displayed = `${component.name} ${
          component.version || component.release
            ? `(${[
                component.version ? `Version ${component.version}` : "",
                component.release ? `Release ${component.release}` : "",
              ].join(", ")})`
            : ""
        }`;
        return component;
      });
    },
  },
};
</script>
