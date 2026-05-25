import axios from "axios";

if (axios.defaults?.headers?.common) {
  const csrfMeta = document.querySelector('meta[name="csrf-token"]');
  if (csrfMeta) {
    axios.defaults.headers.common["X-CSRF-Token"] = csrfMeta.content;
  }
  axios.defaults.headers.common["Accept"] = "application/json";
}

export default axios;
