<template>
  <div class="filter-group" :class="{ 'filter-group-disabled': disabled }">
    <div class="filter-group-header">
      <strong>{{ title }}</strong>
      <span v-if="!disabled" class="reset-link" @click="$emit('reset')">reset</span>
    </div>
    <div class="filter-group-body">
      <div v-for="item in items" :key="item.key" class="filter-item">
        <b-form-checkbox
          :id="`filter-${_uid}-${item.key}`"
          :checked="item.checked"
          :disabled="disabled"
          switch
          size="sm"
          @change="onToggleChange(item.key, $event)"
        >
          {{ item.label }}<template v-if="item.count !== undefined"> ({{ item.count }})</template>
        </b-form-checkbox>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "FilterGroup",
  props: {
    title: {
      type: String,
      required: true,
    },
    items: {
      type: Array,
      required: true,
      // items: [{ key: string, label: string, count?: number, checked: boolean }]
    },
    disabled: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    onToggleChange(key, checked) {
      const updatedItems = this.items.map((item) => {
        if (item.key === key) {
          return { ...item, checked };
        }
        return item;
      });
      this.$emit("update:items", updatedItems);
    },
  },
};
</script>

<style scoped>
.filter-group {
  min-width: 200px;
  border: 1px solid #ced4da;
  border-radius: 0.375rem;
  background-color: #fff;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}

.filter-group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.875rem;
  background-color: #f8f9fa;
  border-bottom: 1px solid #ced4da;
  padding: 0.5rem 0.75rem;
  border-radius: 0.375rem 0.375rem 0 0;
}

.filter-group-body {
  font-size: 0.8125rem;
  padding: 0.5rem 0.75rem;
}

.filter-item {
  padding: 0.125rem 0;
}

.reset-link {
  font-size: 0.75rem;
  color: #007bff;
  cursor: pointer;
}

.reset-link:hover {
  text-decoration: underline;
}

/* Disabled state - greyed out appearance matching Bootstrap pattern */
.filter-group-disabled {
  background-color: #f8f9fa;
}

.filter-group-disabled .filter-group-header {
  color: #6c757d;
}

.filter-group-disabled .filter-group-body {
  pointer-events: none;
  color: #6c757d;
}

/* Grey out switch toggles when disabled */
.filter-group-disabled :deep(.custom-switch .custom-control-label::before) {
  background-color: #dee2e6;
  border-color: #adb5bd;
}

.filter-group-disabled :deep(.custom-switch .custom-control-label::after) {
  background-color: #adb5bd;
}

.filter-group-disabled :deep(.custom-control-label) {
  color: #6c757d;
}
</style>
