export function useDisplayedComponent() {
  function addDisplayNameToComponents(components) {
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
  }

  return { addDisplayNameToComponents };
}
