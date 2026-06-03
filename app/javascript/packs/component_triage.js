import { createVulcanApp } from "../lib/createVulcanApp";
import ComponentTriagePage from "../components/components/ComponentTriagePage.vue";
import linkify from "v-linkify";

document.addEventListener("turbolinks:load", () => {
  createVulcanApp({
    el: "#componenttriage",
    componentName: "Componenttriage",
    component: ComponentTriagePage,
    directives: { linkified: linkify },
  });
});
