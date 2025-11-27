import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import Stigs from "../components/stigs/Stigs.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Stigs
    }
  });

  app.use(createBootstrap());
  app.mount("#Stigs");
});
