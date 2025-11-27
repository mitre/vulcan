import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import Project from "../components/project/Project.vue";
import linkify from "v-linkify";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Project
    }
  });

  app.use(createBootstrap());
  app.directive("linkified", linkify);
  app.mount("#Project");
});
