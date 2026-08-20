import moment from "moment";

export function useDateFormat() {
  function friendlyDateTime(dateTimeString) {
    if (!dateTimeString) return "";
    const normalized = String(dateTimeString).replace(/ UTC$/, "Z").replace(" ", "T");
    return moment(normalized).format("lll");
  }

  return { friendlyDateTime };
}
