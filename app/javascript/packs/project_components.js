import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import ProjectComponents from "../components/components/ProjectComponents.vue";
import linkify from "v-linkify";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Projectcomponents: ProjectComponents
    }
  });

  app.use(createBootstrap());
  app.directive("linkified", linkify);
  app.mount("#projectcomponents");
});
