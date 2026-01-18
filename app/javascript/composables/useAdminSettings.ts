/**
 * useAdminSettings Composable
 *
 * Provides reactive interface for admin settings display.
 * Wraps admin store with computed properties for settings sections.
 */

import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useAdminStore } from '@/stores/admin.store'

export function useAdminSettings() {
  const store = useAdminStore()
  const { settings, settingsLoading, settingsError } = storeToRefs(store)

  // Computed properties for settings sections
  const authentication = computed(() => settings.value?.authentication ?? null)
  const ldap = computed(() => settings.value?.ldap ?? null)
  const oidc = computed(() => settings.value?.oidc ?? null)
  const smtp = computed(() => settings.value?.smtp ?? null)
  const slack = computed(() => settings.value?.slack ?? null)
  const project = computed(() => settings.value?.project ?? null)
  const app = computed(() => settings.value?.app ?? null)
  const banner = computed(() => settings.value?.banner ?? null)

  // Derived properties
  const isLocalLoginEnabled = computed(() => authentication.value?.local_login.enabled ?? false)
  const isLdapEnabled = computed(() => ldap.value?.enabled ?? false)
  const isOidcEnabled = computed(() => oidc.value?.enabled ?? false)
  const isSmtpEnabled = computed(() => smtp.value?.enabled ?? false)
  const isSlackEnabled = computed(() => slack.value?.enabled ?? false)

  /**
   * Load settings
   */
  async function loadSettings(): Promise<void> {
    try {
      await store.fetchSettings()
    }
    catch {
      // Error is already set in store, just swallow the throw
    }
  }

  /**
   * Refresh settings (clear cache and reload)
   */
  async function refresh(): Promise<void> {
    store.clearSettings()
    await loadSettings()
  }

  return {
    // State
    settings,
    loading: settingsLoading,
    error: settingsError,

    // Computed sections
    authentication,
    ldap,
    oidc,
    smtp,
    slack,
    project,
    app,
    banner,

    // Derived flags
    isLocalLoginEnabled,
    isLdapEnabled,
    isOidcEnabled,
    isSmtpEnabled,
    isSlackEnabled,

    // Actions
    loadSettings,
    refresh,
  }
}
