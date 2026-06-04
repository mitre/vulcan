<template>
  <span :id="popoverId" class="user-badge d-inline-flex align-items-center">
    <b-avatar
      :text="initials || undefined"
      :src="avatarUrl || undefined"
      :icon="!initials && !avatarUrl ? 'person-fill' : undefined"
      :variant="variant"
      :size="size"
      class="flex-shrink-0"
    />
    <span v-if="showName && displayName" class="user-badge__name ml-1">
      {{ displayName }}
    </span>
    <b-popover
      v-if="hasPopoverContent"
      :target="popoverId"
      container="body"
      triggers="hover focus"
      placement="top"
      :delay="{ show: 300, hide: 100 }"
    >
      <div class="user-badge__popover">
        <strong v-if="!showName">{{ displayName || "Unknown user" }}</strong>
        <div v-if="email" class="small">{{ email }}</div>
        <div v-if="role" class="small">Role: {{ role }}</div>
      </div>
    </b-popover>
  </span>
</template>

<script>
// Per-pack seed: each esbuild pack loads its own copy of this module and
// picks its own seed, so popoverIds don't collide when (e.g.) the navbar
// pack and the project_component pack both render UserBadges on the same
// page. Combined with this._uid for per-instance uniqueness within a pack.
const moduleSeed = Math.random().toString(36).slice(2, 8);

export default {
  name: "UserBadge",
  props: {
    name: { type: String, default: null },
    email: { type: String, default: null },
    role: { type: String, default: null },
    avatarUrl: { type: String, default: null },
    variant: { type: String, default: "secondary" },
    size: { type: String, default: null },
    showName: { type: Boolean, default: false },
  },
  computed: {
    popoverId() {
      return `user-badge-${moduleSeed}-${this._uid}`;
    },
    displayName() {
      return this.name || this.email || null;
    },
    initials() {
      if (this.name && this.name.trim()) {
        const parts = this.name.trim().split(/\s+/);
        if (parts.length >= 2) {
          return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        }
        return parts[0][0].toUpperCase();
      }
      if (this.email && this.email.trim()) {
        return this.email.trim().slice(0, 2).toUpperCase();
      }
      return null;
    },
    hasPopoverContent() {
      if (this.email) return true;
      if (this.role) return true;
      if (!this.showName && this.displayName) return true;
      return false;
    },
    popoverContent() {
      const lines = [];
      if (!this.showName && this.displayName) lines.push(this.displayName);
      if (this.email) lines.push(this.email);
      if (this.role) lines.push(`Role: ${this.role}`);
      return lines.join("\n");
    },
  },
};
</script>

<style scoped>
.user-badge {
  cursor: default;
}

.user-badge__name {
  font-size: 0.875rem;
}
</style>
