import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import Stigs from "../components/stigs/Stigs.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Stigs
    }
  });

  registerComponents(app);
  app.mount("#Stigs");
});
