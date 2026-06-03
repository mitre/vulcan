import { ref } from "vue";
import { defineStore } from "pinia";

export const useCommentsStore = defineStore("comments", () => {
  const comments = ref({});
  const loading = ref(false);
  const error = ref(null);

  return { comments, loading, error };
});
