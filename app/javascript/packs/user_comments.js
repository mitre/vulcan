import { createVulcanApp } from "../lib/createVulcanApp";
import MyCommentsPage from "../components/users/MyCommentsPage.vue";

document.addEventListener("turbolinks:load", () => {
  createVulcanApp({
    el: "#mycommentspage",
    componentName: "Mycommentspage",
    component: MyCommentsPage,
  });
});
