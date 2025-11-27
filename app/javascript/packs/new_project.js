import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import NewProject from "../components/project/NewProject.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Newproject: NewProject
    }
  });

  app.use(createBootstrap());
  app.mount("#NewProject");
});
