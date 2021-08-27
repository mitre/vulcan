<script>
import axios from "axios";

export default {
  computed: {
    // Authenticity Token for forms
    authenticityToken: function () {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
  },
  mounted: function () {
    axios.defaults.headers.common["X-CSRF-Token"] = this.authenticityToken;
    axios.defaults.headers.common["Accept"] = "application/json";
  },
};
</script>
