import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import Rules from "../components/rules/Rules.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Rules
    }
  });

  registerComponents(app);
  app.mount("#Rules");
});
