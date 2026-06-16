import { usePaths } from "vitepress-openapi";
import spec from "../../data/openapi.json" with { type: "json" };

export default {
  paths() {
    return usePaths({ spec })
      .getTags()
      .map(({ name }) => ({
        params: {
          tag: name,
          pageTitle: `${name} - Vulcan API`,
        },
      }));
  },
};
