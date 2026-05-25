import api from "./baseApi";

export function globalSearch(params) {
  return api.get("/api/search/global", { params });
}

export function getRelatedRules(ruleId) {
  return api.get(`/rules/${ruleId}/search/related_rules`);
}
