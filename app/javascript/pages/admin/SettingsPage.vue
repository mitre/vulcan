<script setup lang="ts">
/**
 * Admin Settings Page
 *
 * Read-only settings viewer (no secrets exposed).
 * Uses useAdminSettings composable for data management.
 *
 * Architecture: Page → Composable → Store → API
 */

import { onMounted } from 'vue'
import PageSpinner from '@/components/shared/PageSpinner.vue'
import { useAdminSettings } from '@/composables'

const {
  loading,
  error,
  authentication,
  ldap,
  oidc,
  smtp,
  slack,
  project,
  app,
  loadSettings,
} = useAdminSettings()

onMounted(loadSettings)
</script>

<template>
  <div class="admin-settings">
    <h1 class="h3 mb-4">
      <i class="bi bi-sliders me-2" />
      System Settings
      <BBadge variant="secondary" class="ms-2 fs-6 fw-normal">
        Read Only
      </BBadge>
    </h1>

    <!-- Loading state -->
    <PageSpinner v-if="loading" message="Loading settings..." />

    <!-- Error state -->
    <BAlert v-else-if="error" variant="danger" show>
      {{ error }}
      <BButton size="sm" variant="outline-danger" class="ms-2" @click="loadSettings">
        Retry
      </BButton>
    </BAlert>

    <!-- Settings display -->
    <template v-else>
      <div class="row g-4">
        <!-- Authentication -->
        <div class="col-lg-6">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-shield-lock me-2" />
                Authentication
              </h5>
            </div>
            <ul class="list-group list-group-flush">
              <li class="list-group-item d-flex justify-content-between">
                <span>Local Login</span>
                <BBadge :variant="authentication?.local_login.enabled ? 'success' : 'secondary'">
                  {{ authentication?.local_login.enabled ? 'Enabled' : 'Disabled' }}
                </BBadge>
              </li>
              <li class="list-group-item d-flex justify-content-between">
                <span>Email Confirmation</span>
                <BBadge :variant="authentication?.local_login.email_confirmation ? 'success' : 'secondary'">
                  {{ authentication?.local_login.email_confirmation ? 'Required' : 'Not Required' }}
                </BBadge>
              </li>
              <li class="list-group-item d-flex justify-content-between">
                <span>User Registration</span>
                <BBadge :variant="authentication?.user_registration.enabled ? 'success' : 'secondary'">
                  {{ authentication?.user_registration.enabled ? 'Open' : 'Invite Only' }}
                </BBadge>
              </li>
              <li class="list-group-item d-flex justify-content-between">
                <span>Session Timeout</span>
                <span class="text-muted">{{ authentication?.local_login.session_timeout_minutes ?? 0 }} minutes</span>
              </li>
            </ul>
          </div>
        </div>

        <!-- Account Lockout -->
        <div class="col-lg-6">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-lock me-2" />
                Account Lockout
              </h5>
            </div>
            <ul class="list-group list-group-flush">
              <li class="list-group-item d-flex justify-content-between">
                <span>Status</span>
                <BBadge :variant="authentication?.lockable.enabled ? 'success' : 'secondary'">
                  {{ authentication?.lockable.enabled ? 'Enabled' : 'Disabled' }}
                </BBadge>
              </li>
              <li class="list-group-item d-flex justify-content-between">
                <span>Max Failed Attempts</span>
                <span class="text-muted">{{ authentication?.lockable.max_attempts ?? 0 }}</span>
              </li>
              <li class="list-group-item d-flex justify-content-between">
                <span>Auto-Unlock After</span>
                <span class="text-muted">{{ authentication?.lockable.unlock_in_minutes ?? 0 }} minutes</span>
              </li>
            </ul>
          </div>
        </div>

        <!-- LDAP -->
        <div class="col-lg-6">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-diagram-3 me-2" />
                LDAP
              </h5>
            </div>
            <ul class="list-group list-group-flush">
              <li class="list-group-item d-flex justify-content-between">
                <span>Status</span>
                <BBadge :variant="ldap?.enabled ? 'success' : 'secondary'">
                  {{ ldap?.enabled ? 'Enabled' : 'Disabled' }}
                </BBadge>
              </li>
              <li v-if="ldap?.enabled" class="list-group-item d-flex justify-content-between">
                <span>Button Title</span>
                <span class="text-muted">{{ ldap.title }}</span>
              </li>
            </ul>
          </div>
        </div>

        <!-- OIDC -->
        <div class="col-lg-6">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-key me-2" />
                OIDC / SSO
              </h5>
            </div>
            <ul class="list-group list-group-flush">
              <li class="list-group-item d-flex justify-content-between">
                <span>Status</span>
                <BBadge :variant="oidc?.enabled ? 'success' : 'secondary'">
                  {{ oidc?.enabled ? 'Enabled' : 'Disabled' }}
                </BBadge>
              </li>
              <li v-if="oidc?.enabled" class="list-group-item d-flex justify-content-between">
                <span>Button Title</span>
                <span class="text-muted">{{ oidc.title }}</span>
              </li>
              <li v-if="oidc?.enabled && oidc.issuer" class="list-group-item d-flex justify-content-between">
                <span>Issuer</span>
                <code class="small text-truncate" style="max-width: 200px">{{ oidc.issuer }}</code>
              </li>
            </ul>
          </div>
        </div>

        <!-- Email/SMTP -->
        <div class="col-lg-6">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-envelope me-2" />
                Email (SMTP)
              </h5>
            </div>
            <ul class="list-group list-group-flush">
              <li class="list-group-item d-flex justify-content-between">
                <span>Status</span>
                <BBadge :variant="smtp?.enabled ? 'success' : 'secondary'">
                  {{ smtp?.enabled ? 'Enabled' : 'Disabled' }}
                </BBadge>
              </li>
              <li v-if="smtp?.enabled" class="list-group-item d-flex justify-content-between">
                <span>Server</span>
                <code class="small">{{ smtp.address }}:{{ smtp.port }}</code>
              </li>
            </ul>
          </div>
        </div>

        <!-- Integrations -->
        <div class="col-lg-6">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-plug me-2" />
                Integrations
              </h5>
            </div>
            <ul class="list-group list-group-flush">
              <li class="list-group-item d-flex justify-content-between">
                <span>Slack</span>
                <BBadge :variant="slack?.enabled ? 'success' : 'secondary'">
                  {{ slack?.enabled ? 'Enabled' : 'Disabled' }}
                </BBadge>
              </li>
            </ul>
          </div>
        </div>

        <!-- Application -->
        <div class="col-12">
          <div class="card">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-app me-2" />
                Application
              </h5>
            </div>
            <ul class="list-group list-group-flush">
              <li class="list-group-item d-flex justify-content-between">
                <span>App URL</span>
                <code class="small">{{ app?.url }}</code>
              </li>
              <li class="list-group-item d-flex justify-content-between">
                <span>Contact Email</span>
                <code class="small">{{ app?.contact_email }}</code>
              </li>
              <li class="list-group-item d-flex justify-content-between">
                <span>Project Creation</span>
                <BBadge :variant="project?.create_permission_enabled ? 'warning' : 'success'">
                  {{ project?.create_permission_enabled ? 'Requires Permission' : 'All Users' }}
                </BBadge>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Info notice -->
      <BAlert variant="info" show class="mt-4">
        <i class="bi bi-info-circle me-2" />
        Settings are configured via <code>vulcan.yml</code> or environment variables.
        Changes require application restart.
      </BAlert>
    </template>
  </div>
</template>
