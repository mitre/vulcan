import api from "./baseApi";

// Sign-out is intentionally NOT an api function: it must be a navigational
// rails-ujs DELETE link (see navbar App.vue) so Devise's HTML flow sets the
// "Signed out successfully." flash and redirects to the sign-in page where
// the Toaster renders it. An ajax DELETE gets a flashless 204.

export function acknowledgeConsent() {
  return api.post("/consent/acknowledge");
}
