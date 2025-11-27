import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import Rules from "../components/rules/Rules.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Rules
    }
  });

  app.use(createBootstrap());
  app.mount("#Rules");
});
