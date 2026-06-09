import DefaultTheme from "vitepress/theme";
import { theme, useOpenapi, usePlayground } from "vitepress-openapi/client";
import "vitepress-openapi/dist/style.css";
import Mermaid from "./Mermaid.vue";
import ColorSwatch from "./ColorSwatch.vue";
import "./custom.css";

import specRaw from "../../data/openapi.json";

// Strip cookieAuth from the spec for public docs — only tokenAuth is
// useful for external consumers. Cookie auth is internal to the Rails app.
const spec = JSON.parse(JSON.stringify(specRaw));
if (spec.components?.securitySchemes?.cookieAuth) {
  delete spec.components.securitySchemes.cookieAuth;
}
if (Array.isArray(spec.security)) {
  spec.security = spec.security.filter((s) => !("cookieAuth" in s));
}
for (const pathObj of Object.values(spec.paths || {})) {
  for (const method of Object.values(pathObj)) {
    if (method && Array.isArray(method.security)) {
      method.security = method.security.filter((s) => !("cookieAuth" in s));
    }
  }
}
if (Array.isArray(spec.servers)) {
  spec.servers = spec.servers.filter((s) => s.url !== "/");
}

export default {
  ...DefaultTheme,
  async enhanceApp({ app }) {
    useOpenapi({
      spec,
      config: {
        spec: {
          groupByTags: true,
        },
        operation: {
          defaultBaseUrl: "https://vulcan.example.com",
        },
        server: {
          allowCustomServer: true,
        },
        storage: {
          persistAuth: true,
        },
      },
    });

    const playground = usePlayground();
    playground.setSecuritySchemeDefaultValues({
      tokenAuth: "Token vulcan_your_token_here",
    });

    theme.enhanceApp({ app });
    app.component("Mermaid", Mermaid);
    app.component("ColorSwatch", ColorSwatch);
  },
};
