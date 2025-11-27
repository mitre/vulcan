import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import Users from "../components/users/Users.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Users
    }
  });

  app.use(createBootstrap());
  app.mount("#users");
});
