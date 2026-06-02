import DefaultTheme from "vitepress/theme";
import Mermaid from "./Mermaid.vue";
import ColorSwatch from "./ColorSwatch.vue";
import "./custom.css";

export default {
  ...DefaultTheme,
  enhanceApp({ app }) {
    app.component("Mermaid", Mermaid);
    app.component("ColorSwatch", ColorSwatch);
  },
};
