import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const signedIn = computed(() => !!user.value)
  const isAdmin = computed(() => user.value?.admin === true)

  function setUser(userData) {
    user.value = userData
  }

  function clearUser() {
    user.value = null
  }

  return {
    user,
    signedIn,
    isAdmin,
    setUser,
    clearUser
  }
})
