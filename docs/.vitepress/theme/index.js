import { defineComponent, h, watch } from "vue";
import { useData } from "vitepress";
import DefaultTheme from "vitepress/theme";
import { theme, useOpenapi, usePlayground } from "vitepress-openapi/client";
import "vitepress-openapi/dist/style.css";
import Mermaid from "./Mermaid.vue";
import ColorSwatch from "./ColorSwatch.vue";
import "./custom.css";

// Served in-app, the reader's theme choice is one preference shared with the
// application: the app mirrors its stored choice into this site's own storage
// key (which the pre-paint init script reads), and this wrapper completes the
// round trip — flipping the appearance switch here records the choice under
// the application's key too, so the app follows on its next page load.
// (The link back into the application is ordinary nav configuration in
// config.mjs, not layout work.)
const Layout = defineComponent({
  name: "VulcanDocsLayout",
  setup() {
    const { isDark, theme: themeConfig } = useData();

    if (typeof window !== "undefined" && themeConfig.value.docsTarget?.inApp) {
      watch(isDark, (dark) => {
        window.localStorage.setItem("vulcan-theme", dark ? "dark" : "light");
      });
    }

    return () => h(DefaultTheme.Layout);
  },
});

import specRaw from "../../site/data/openapi.json";

// Cookie auth and the same-origin server entry are meaningful only when the
// reader is inside a running instance. On the published site they describe
// something the reader cannot reach, so they are removed; served in-app they
// are the whole point, because the reader's own session authenticates them.
function specForTarget(target) {
  const spec = JSON.parse(JSON.stringify(specRaw));

  if (target.api.sameOrigin) {
    return spec;
  }

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

  return spec;
}

export default {
  ...DefaultTheme,
  Layout,
  async enhanceApp({ app, siteData }) {
    const target = siteData.value.themeConfig.docsTarget;

    useOpenapi({
      spec: specForTarget(target),
      config: {
        spec: {
          groupByTags: true,
        },
        operation: {
          // Served in-app the specification's own same-origin server is
          // correct, so no default is imposed.
          ...(target.api.defaultBaseUrl
            ? { defaultBaseUrl: target.api.defaultBaseUrl }
            : {}),
        },
        server: {
          // Pointing the playground at another host from inside a running
          // instance is a footgun rather than a feature.
          allowCustomServer: target.api.allowCustomServer,

          // Served in-app, requests go to the instance the reader is already
          // signed in to. Two constraints, both learned from the library's
          // source rather than its documentation:
          //
          // The value must be an ABSOLUTE origin. The playground builds
          // `${server}${path}` and passes it to `new URL()` with no base, so a
          // relative server such as "/" throws before anything is sent.
          //
          // Entries must be OBJECTS carrying a `url`. The documented signature
          // says an array of strings, but OAOperationContext reads
          // `servers[0]?.url`, so strings resolve to undefined and the base
          // silently falls back to somewhere that is not this origin — which
          // the connect-src policy then correctly refuses.
          //
          // Resolved in the browser because a static build has no origin to
          // bake in.
          ...(target.api.sameOrigin
            ? {
                getServers: () =>
                  typeof window === "undefined"
                    ? []
                    : [{ url: window.location.origin }],
              }
            : {}),
        },
        storage: {
          persistAuth: true,
        },
      },
    });

    // A reader inside an instance is already authenticated by their session,
    // so there is no placeholder to prefill. Reads work as they are; writes
    // need a personal access token, because the application rejects
    // session-authenticated writes without a CSRF token and this playground
    // has no hook for one.
    if (target.api.prefillToken) {
      const playground = usePlayground();
      playground.setSecuritySchemeDefaultValues({
        tokenAuth: target.api.prefillToken,
      });
    }

    theme.enhanceApp({ app });
    app.component("Mermaid", Mermaid);
    app.component("ColorSwatch", ColorSwatch);
  },
};
