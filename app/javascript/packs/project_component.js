import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import ProjectComponent from "../components/components/ProjectComponent.vue";
import linkify from "v-linkify";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Projectcomponent: ProjectComponent
    }
  });

  registerComponents(app);
  app.directive("linkified", linkify);
  app.mount("#projectcomponent");
});
