import { createVulcanApp } from "../lib/createVulcanApp";
import ProjectTriagePage from "../components/project/ProjectTriagePage.vue";
import linkify from "v-linkify";

document.addEventListener("turbolinks:load", () => {
  createVulcanApp({
    el: "#projecttriage",
    componentName: "Projecttriage",
    component: ProjectTriagePage,
    directives: { linkified: linkify },
  });
});
