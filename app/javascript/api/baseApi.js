import axios from "axios";

const api = axios.create({
  headers: {
    common: {
      Accept: "application/json",
    },
  },
});

const csrfMeta = document.querySelector('meta[name="csrf-token"]');
if (csrfMeta) {
  api.defaults.headers.common["X-CSRF-Token"] = csrfMeta.content;
}

export default api;
