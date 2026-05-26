import api from "./baseApi";

export function getVersion() {
  return api.get("/api/version");
}
