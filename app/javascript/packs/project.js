import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import Project from "../components/project/Project.vue";
import linkify from "v-linkify";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Project
    }
  });

  registerComponents(app);
  app.directive("linkified", linkify);
  app.mount("#Project");
});
