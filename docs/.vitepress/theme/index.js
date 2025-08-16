import DefaultTheme from "vitepress/theme";
import Mermaid from "./Mermaid.vue";
import "./custom.css";

export default {
  ...DefaultTheme,
  enhanceApp({ app }) {
    // Register Mermaid component globally
    app.component("Mermaid", Mermaid);
  },
};
