import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import Stig from "../components/stigs/Stig.vue";
import linkify from "v-linkify";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Stig
    }
  });

  app.use(createBootstrap());
  app.directive("linkified", linkify);
  app.mount("#stig");
});
