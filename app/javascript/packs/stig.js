import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import Stig from "../components/stigs/Stig.vue";
import linkify from "v-linkify";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Stig
    }
  });

  registerComponents(app);
  app.directive("linkified", linkify);
  app.mount("#stig");
});
