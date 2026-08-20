import { createVulcanApp } from "../lib/createVulcanApp";
import MyCommentsPage from "../components/users/MyCommentsPage.vue";

document.addEventListener("DOMContentLoaded", () => {
  createVulcanApp({
    el: "#mycommentspage",
    componentName: "Mycommentspage",
    component: MyCommentsPage,
  });
});
