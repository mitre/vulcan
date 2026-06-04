import { createVulcanApp } from "../lib/createVulcanApp";
import ProjectComponent from "../components/components/ProjectComponent.vue";
import linkify from "v-linkify";

document.addEventListener("turbolinks:load", () => {
  createVulcanApp({
    el: "#projectcomponent",
    componentName: "Projectcomponent",
    component: ProjectComponent,
    directives: { linkified: linkify },
  });
});
