import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import ProjectComponent from "../components/components/ProjectComponent.vue";
import linkify from "v-linkify";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Projectcomponent: ProjectComponent
    }
  });

  app.use(createBootstrap());
  app.directive("linkified", linkify);
  app.mount("#projectcomponent");
});
