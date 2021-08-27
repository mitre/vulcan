<script>
// This is meant to be a very simple but centralized mixin
// that controls how dates are formatted for the frontend.
import moment from "moment";
export default {
  methods: {
    friendlyDateTime: function (dateTimeString) {
      return moment(dateTimeString).format("lll");
    },
  },
};
</script>
