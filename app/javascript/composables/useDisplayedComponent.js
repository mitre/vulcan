export function useDisplayedComponent() {
  // Adds a `displayed` label to each component: "Name (Version X, Release Y)",
  // including only the parts that are present — "Name (Version X)", "Name
  // (Release Y)", or the bare "Name". Mutates the objects and returns the array
  // (consumers rely on prop-array mutation for reactivity).
  function addDisplayNameToComponents(components) {
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
  }

  return { addDisplayNameToComponents };
}
