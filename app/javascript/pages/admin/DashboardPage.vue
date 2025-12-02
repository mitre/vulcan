<script setup lang="ts">
/**
 * Admin Dashboard Page
 *
 * Overview stats and recent activity feed.
 * Uses useAdminDashboard composable for data management.
 *
 * Architecture: Page → Composable → Store → API
 */

import { onMounted } from 'vue'
import PageSpinner from '@/components/shared/PageSpinner.vue'
import { useAdminDashboard } from '@/composables'

const {
  loading,
  error,
  userStats,
  projectStats,
  stigStats,
  srgStats,
  componentStats,
  recentActivity,
  loadStats,
  timeAgo,
} = useAdminDashboard()

onMounted(loadStats)
</script>

<template>
  <div class="admin-dashboard">
    <h1 class="h3 mb-4">
      <i class="bi bi-speedometer2 me-2" />
      Admin Dashboard
    </h1>

    <!-- Loading state -->
    <PageSpinner v-if="loading" message="Loading stats..." />

    <!-- Error state -->
    <BAlert v-else-if="error" variant="danger" show>
      {{ error }}
      <BButton size="sm" variant="outline-danger" class="ms-2" @click="loadStats">
        Retry
      </BButton>
    </BAlert>

    <!-- Stats cards -->
    <template v-else>
      <div class="row g-3 mb-4">
        <!-- Users card -->
        <div class="col-sm-6 col-lg-3">
          <div class="card h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between">
                <div>
                  <h2 class="card-title h4 mb-0">
                    {{ userStats?.total ?? 0 }}
                  </h2>
                  <p class="card-text text-muted mb-0">
                    Users
                  </p>
                </div>
                <div class="text-primary fs-1">
                  <i class="bi bi-people" />
                </div>
              </div>
              <div class="small text-muted mt-2">
                {{ userStats?.local ?? 0 }} local, {{ userStats?.external ?? 0 }} external
              </div>
            </div>
          </div>
        </div>

        <!-- Projects card -->
        <div class="col-sm-6 col-lg-3">
          <div class="card h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between">
                <div>
                  <h2 class="card-title h4 mb-0">
                    {{ projectStats?.total ?? 0 }}
                  </h2>
                  <p class="card-text text-muted mb-0">
                    Projects
                  </p>
                </div>
                <div class="text-success fs-1">
                  <i class="bi bi-folder" />
                </div>
              </div>
              <div class="small text-muted mt-2">
                {{ projectStats?.recent ?? 0 }} created this month
              </div>
            </div>
          </div>
        </div>

        <!-- STIGs card -->
        <div class="col-sm-6 col-lg-3">
          <div class="card h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between">
                <div>
                  <h2 class="card-title h4 mb-0">
                    {{ stigStats?.total ?? 0 }}
                  </h2>
                  <p class="card-text text-muted mb-0">
                    STIGs
                  </p>
                </div>
                <div class="text-info fs-1">
                  <i class="bi bi-file-earmark-lock" />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- SRGs card -->
        <div class="col-sm-6 col-lg-3">
          <div class="card h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between">
                <div>
                  <h2 class="card-title h4 mb-0">
                    {{ srgStats?.total ?? 0 }}
                  </h2>
                  <p class="card-text text-muted mb-0">
                    SRGs
                  </p>
                </div>
                <div class="text-warning fs-1">
                  <i class="bi bi-file-earmark-text" />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Components card -->
        <div class="col-sm-6 col-lg-3">
          <div class="card h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between">
                <div>
                  <h2 class="card-title h4 mb-0">
                    {{ componentStats?.total ?? 0 }}
                  </h2>
                  <p class="card-text text-muted mb-0">
                    Components
                  </p>
                </div>
                <div class="text-purple fs-1">
                  <i class="bi bi-puzzle" />
                </div>
              </div>
              <div class="small text-muted mt-2">
                {{ componentStats?.released ?? 0 }} released
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Activity -->
      <div class="card">
        <div class="card-header">
          <h5 class="mb-0">
            <i class="bi bi-activity me-2" />
            Recent Activity
          </h5>
        </div>
        <div class="card-body p-0">
          <div class="list-group list-group-flush">
            <div
              v-for="activity in recentActivity"
              :key="activity.id"
              class="list-group-item d-flex justify-content-between align-items-start"
            >
              <div>
                <strong>{{ activity.user_name }}</strong>
                <span class="text-muted">{{ activity.action }}</span>
                <span>{{ activity.auditable_type }}</span>
                <span v-if="activity.auditable_name" class="text-primary">
                  "{{ activity.auditable_name }}"
                </span>
              </div>
              <small class="text-muted text-nowrap">
                {{ timeAgo(activity.created_at) }}
              </small>
            </div>
            <div
              v-if="!recentActivity.length"
              class="list-group-item text-muted text-center"
            >
              No recent activity
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
