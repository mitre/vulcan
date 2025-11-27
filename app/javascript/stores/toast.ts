import { defineStore } from 'pinia'
import { useToast } from 'bootstrap-vue-next'

export const useToastStore = defineStore('toast', () => {
  const toast = useToast()

  function show(message, options = {}) {
    toast?.show({
      props: {
        body: message,
        title: options.title || 'Notification',
        variant: options.variant || 'info',
        solid: true
      }
    })
  }

  function success(message, title = 'Success') {
    show(message, { title, variant: 'success' })
  }

  function error(message, title = 'Error') {
    show(message, { title, variant: 'danger' })
  }

  function warning(message, title = 'Warning') {
    show(message, { title, variant: 'warning' })
  }

  function info(message, title = 'Info') {
    show(message, { title, variant: 'info' })
  }

  return {
    show,
    success,
    error,
    warning,
    info
  }
})
