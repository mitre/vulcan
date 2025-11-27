import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import ProjectComponents from "../components/components/ProjectComponents.vue";
import linkify from "v-linkify";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Projectcomponents: ProjectComponents
    }
  });

  registerComponents(app);
  app.directive("linkified", linkify);
  app.mount("#projectcomponents");
});
