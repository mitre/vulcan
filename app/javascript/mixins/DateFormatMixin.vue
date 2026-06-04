<script>
// This is meant to be a very simple but centralized mixin
// that controls how dates are formatted for the frontend.
import moment from "moment";
export default {
  methods: {
    friendlyDateTime: function (dateTimeString) {
      if (!dateTimeString) return "";
      const normalized = String(dateTimeString).replace(/ UTC$/, "Z").replace(" ", "T");
      return moment(normalized).format("lll");
    },
  },
};
</script>
