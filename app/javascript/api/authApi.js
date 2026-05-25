import api from "./baseApi";

export function signOut(signOutPath) {
  return api.delete(signOutPath);
}

export function acknowledgeConsent() {
  return api.post("/consent/acknowledge");
}
