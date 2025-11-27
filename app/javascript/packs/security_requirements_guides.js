import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import SecurityRequirementsGuides from "../components/security_requirements_guides/SecurityRequirementsGuides.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Securityrequirementsguides: SecurityRequirementsGuides
    }
  });

  app.use(createBootstrap());
  app.mount("#SecurityRequirementsGuides");
});
