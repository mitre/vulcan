import { createVulcanApp } from "../lib/createVulcanApp";
import ProjectTriagePage from "../components/project/ProjectTriagePage.vue";
import linkify from "v-linkify";
import { createTriageRouter } from "../router/triagePage";

document.addEventListener("DOMContentLoaded", () => {
  createVulcanApp({
    el: "#projecttriage",
    componentName: "Projecttriage",
    component: ProjectTriagePage,
    directives: { linkified: linkify },
    router: createTriageRouter(),
  });
});
