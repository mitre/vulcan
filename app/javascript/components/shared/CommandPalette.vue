<script setup lang="ts">
/**
 * CommandPalette - Global search and navigation component
 *
 * Built with Reka UI Listbox primitives (not Combobox) to avoid
 * internal filtering conflicts with server-side search.
 *
 * Based on Nuxt UI v4 CommandPalette patterns.
 *
 * Features:
 * - Fuzzy search for Quick Actions (Fuse.js client-side)
 * - Server-side search for Projects, Components, Requirements (pg_search)
 * - Keyboard navigation (Cmd+J to open, arrows to navigate)
 * - Recent items history
 * - Grouped results
 */

import type { CommandPaletteItem } from '@/types/command-palette'
import {
  DialogContent,
  DialogDescription,
  DialogOverlay,
  DialogPortal,
  DialogRoot,
  DialogTitle,
  ListboxContent,
  ListboxGroup,
  ListboxGroupLabel,
  ListboxItem,
  ListboxRoot,
  VisuallyHidden,
} from 'reka-ui'
import { computed, nextTick, ref, watch } from 'vue'
import Highlighter from 'vue-highlight-words'
import { useRouter } from 'vue-router'
import { useCommandPalette } from '@/composables/useCommandPalette'
import { useGlobalSearch } from '@/composables/useGlobalSearch'

// Use composables
const { open, searchTerm, close, getKeySymbol } = useCommandPalette()
const {
  loading,
  groups,
  totalResults,
  addToRecent,
  reset,
} = useGlobalSearch(searchTerm)

const router = useRouter()
const inputRef = ref<HTMLInputElement | null>(null)
const listboxRef = ref<InstanceType<typeof ListboxContent> | null>(null)

// Search words for highlighting (split search term into words)
const searchWords = computed(() => {
  const term = searchTerm.value.trim()
  if (!term) return []
  return term.split(/\s+/).filter(word => word.length >= 2)
})

// Focus input when dialog opens
// Use multiple nextTick cycles to ensure DOM is fully rendered
watch(open, async (isOpen) => {
  if (isOpen) {
    // Wait for dialog to render, then focus
    await nextTick()
    await nextTick()
    // Use setTimeout as fallback for dialog animation
    setTimeout(() => {
      inputRef.value?.focus()
    }, 50)
  }
  else {
    reset()
  }
})

// Track highlighted index for keyboard navigation
const highlightedIndex = ref(0)

// Flatten all items from groups for keyboard navigation
const allItems = computed(() => {
  return groups.value.flatMap(group => group.items)
})

// Reset highlighted index when results change
watch(groups, () => {
  highlightedIndex.value = 0
})

// Handle keyboard navigation from input
function handleInputKeydown(event: KeyboardEvent) {
  const items = allItems.value
  if (items.length === 0) return

  switch (event.key) {
    case 'ArrowDown':
      event.preventDefault()
      highlightedIndex.value = Math.min(highlightedIndex.value + 1, items.length - 1)
      scrollToHighlighted()
      break
    case 'ArrowUp':
      event.preventDefault()
      highlightedIndex.value = Math.max(highlightedIndex.value - 1, 0)
      scrollToHighlighted()
      break
    case 'Enter':
      event.preventDefault()
      if (items[highlightedIndex.value]) {
        handleSelect(items[highlightedIndex.value])
      }
      break
  }
}

// Scroll highlighted item into view
function scrollToHighlighted() {
  nextTick(() => {
    const highlighted = document.querySelector('.command-palette-item.is-highlighted')
    highlighted?.scrollIntoView({ block: 'nearest' })
  })
}

// Handle item selection
function handleSelect(item: CommandPaletteItem) {
  if (!item) return

  // Add to recent items
  addToRecent(item)

  // Close palette
  close()

  // Navigate
  if (item.to) {
    router.push(item.to)
  }
  else if (item.href) {
    window.open(item.href, '_blank')
  }
  else if (item.onSelect) {
    item.onSelect()
  }
}

// Get icon class for item
function getItemIcon(item: CommandPaletteItem): string {
  if (item.icon) return `bi ${item.icon}`
  return 'bi bi-circle'
}

// Check if item is currently highlighted
function isHighlighted(item: CommandPaletteItem): boolean {
  const items = allItems.value
  const index = items.findIndex(i => i.id === item.id)
  return index === highlightedIndex.value
}
</script>

<template>
  <DialogRoot v-model:open="open">
    <DialogPortal>
      <!-- Overlay -->
      <DialogOverlay class="command-palette-overlay" />

      <!-- Dialog Content -->
      <DialogContent
        class="command-palette-dialog"
        @escape-key-down="close"
      >
        <!-- Accessibility: Hidden title and description -->
        <VisuallyHidden>
          <DialogTitle>Command Palette</DialogTitle>
          <DialogDescription>
            Search for projects, components, requirements, or quick actions
          </DialogDescription>
        </VisuallyHidden>

        <!-- Listbox for navigation -->
        <ListboxRoot
          class="command-palette-root"
          :model-value="null"
          @update:model-value="handleSelect"
        >
          <!-- Search Input Header -->
          <div class="command-palette-header">
            <i class="bi bi-search text-muted" />
            <input
              ref="inputRef"
              v-model="searchTerm"
              type="text"
              class="command-palette-input"
              placeholder="Search projects, components, requirements..."
              @keydown="handleInputKeydown"
              @keydown.escape="close"
            >
            <span v-if="loading" class="spinner-border spinner-border-sm text-muted" />
            <kbd v-else class="command-palette-kbd">ESC</kbd>
          </div>

          <!-- Results -->
          <ListboxContent ref="listboxRef" class="command-palette-content" tabindex="0">
            <!-- Empty state -->
            <div v-if="groups.length === 0" class="command-palette-empty">
              <template v-if="searchTerm && searchTerm.length >= 2 && !loading">
                <i class="bi bi-search me-2" />
                No results found for "{{ searchTerm }}"
              </template>
              <template v-else-if="searchTerm && searchTerm.length < 2">
                <i class="bi bi-keyboard me-2" />
                Type at least 2 characters to search...
              </template>
              <template v-else-if="!searchTerm">
                <i class="bi bi-keyboard me-2" />
                Start typing to search...
              </template>
            </div>

            <!-- Grouped results -->
            <ListboxGroup
              v-for="group in groups"
              :key="group.id"
              class="command-palette-group"
            >
              <ListboxGroupLabel class="command-palette-group-label">
                <i v-if="group.icon" :class="`bi ${group.icon}`" class="me-1" />
                {{ group.label }}
              </ListboxGroupLabel>

              <ListboxItem
                v-for="item in group.items"
                :key="String(item.id)"
                :value="item"
                class="command-palette-item" :class="[{ 'is-highlighted': isHighlighted(item) }]"
              >
                <div class="d-flex align-items-center gap-2 w-100">
                  <i :class="getItemIcon(item)" class="command-palette-item-icon" />
                  <div class="flex-grow-1 overflow-hidden">
                    <div class="command-palette-item-label text-truncate">
                      <Highlighter
                        v-if="searchWords.length > 0"
                        highlight-class-name="search-highlight"
                        :search-words="searchWords"
                        :auto-escape="true"
                        :text-to-highlight="item.label"
                      />
                      <template v-else>
                        {{ item.label }}
                      </template>
                    </div>
                    <div
                      v-if="item.description || item.suffix"
                      class="command-palette-item-description text-truncate"
                    >
                      <template v-if="item.description">
                        <Highlighter
                          v-if="searchWords.length > 0"
                          highlight-class-name="search-highlight"
                          :search-words="searchWords"
                          :auto-escape="true"
                          :text-to-highlight="item.description"
                        />
                        <template v-else>
                          {{ item.description }}
                        </template>
                      </template>
                      <span v-if="item.suffix" class="command-palette-item-suffix">
                        {{ item.suffix }}
                      </span>
                    </div>
                  </div>
                  <i class="bi bi-arrow-return-left command-palette-item-hint" />
                </div>
              </ListboxItem>
            </ListboxGroup>
          </ListboxContent>

          <!-- Footer with cross-platform shortcuts -->
          <div class="command-palette-footer">
            <div class="d-flex gap-3 text-muted small">
              <span class="d-flex align-items-center gap-1">
                <kbd>{{ getKeySymbol('Up') }}</kbd>
                <kbd>{{ getKeySymbol('Down') }}</kbd>
                <span>Navigate</span>
              </span>
              <span class="d-flex align-items-center gap-1">
                <kbd>{{ getKeySymbol('Enter') }}</kbd>
                <span>Select</span>
              </span>
              <span class="d-flex align-items-center gap-1">
                <kbd>{{ getKeySymbol('Escape') }}</kbd>
                <span>Close</span>
              </span>
            </div>
            <span v-if="totalResults > 0" class="text-muted small">
              {{ totalResults }} results
            </span>
          </div>
        </ListboxRoot>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>

<style scoped>
/* Overlay */
.command-palette-overlay {
  position: fixed;
  inset: 0;
  z-index: 1050;
  background-color: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(2px);
}

/* Dialog */
.command-palette-dialog {
  position: fixed;
  top: 15%;
  left: 50%;
  transform: translateX(-50%);
  z-index: 1051;
  width: 100%;
  max-width: 600px;
  max-height: 70vh;
  background-color: var(--bs-body-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: var(--bs-border-radius-lg);
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  overflow: hidden;
}

/* Root container */
.command-palette-root {
  display: flex;
  flex-direction: column;
  height: 100%;
}

/* Header with search input */
.command-palette-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--bs-border-color);
}

.command-palette-input {
  flex: 1;
  border: none;
  background: transparent;
  color: var(--bs-body-color);
  font-size: 1rem;
  outline: none;
}

.command-palette-input::placeholder {
  color: var(--bs-secondary-color);
}

.command-palette-kbd {
  padding: 0.125rem 0.375rem;
  font-size: 0.75rem;
  font-family: var(--bs-font-monospace);
  background-color: var(--bs-secondary-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: var(--bs-border-radius-sm);
  color: var(--bs-secondary-color);
}

/* Content area */
.command-palette-content {
  flex: 1;
  overflow-y: auto;
  padding: 0.5rem;
  max-height: calc(70vh - 120px);
}

/* Empty state */
.command-palette-empty {
  padding: 2rem;
  text-align: center;
  color: var(--bs-secondary-color);
}

/* Group */
.command-palette-group {
  margin-bottom: 0.5rem;
}

.command-palette-group:last-child {
  margin-bottom: 0;
}

.command-palette-group-label {
  padding: 0.375rem 0.75rem;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--bs-secondary-color);
}

/* Item */
.command-palette-item {
  display: flex;
  align-items: center;
  padding: 0.5rem 0.75rem;
  border-radius: var(--bs-border-radius);
  cursor: pointer;
  transition: background-color 0.15s ease;
}

/* Reka UI data attribute styling + custom highlight class */
.command-palette-item[data-highlighted],
.command-palette-item.is-highlighted {
  background-color: var(--bs-primary-bg-subtle);
}

.command-palette-item[data-disabled] {
  opacity: 0.5;
  pointer-events: none;
}

.command-palette-item-icon {
  width: 1.25rem;
  text-align: center;
  color: var(--bs-secondary-color);
}

.command-palette-item[data-highlighted] .command-palette-item-icon,
.command-palette-item.is-highlighted .command-palette-item-icon {
  color: var(--bs-primary);
}

.command-palette-item-label {
  font-weight: 500;
  color: var(--bs-body-color);
}

.command-palette-item-description {
  font-size: 0.75rem;
  color: var(--bs-secondary-color);
}

.command-palette-item-suffix {
  margin-left: 0.5rem;
  padding: 0.125rem 0.375rem;
  font-size: 0.6875rem;
  font-weight: 500;
  color: var(--bs-info-text-emphasis);
  background-color: var(--bs-info-bg-subtle);
  border-radius: var(--bs-border-radius-sm);
}

/* Search term highlighting */
:deep(.search-highlight) {
  background-color: var(--bs-warning-bg-subtle);
  color: var(--bs-warning-text-emphasis);
  padding: 0 0.125rem;
  border-radius: 2px;
  font-weight: 600;
}

.command-palette-item-hint {
  color: var(--bs-secondary-color);
  opacity: 0;
  transition: opacity 0.15s ease;
}

.command-palette-item[data-highlighted] .command-palette-item-hint,
.command-palette-item.is-highlighted .command-palette-item-hint {
  opacity: 1;
}

/* Footer */
.command-palette-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 1rem;
  border-top: 1px solid var(--bs-border-color);
  background-color: var(--bs-secondary-bg);
}

.command-palette-footer kbd {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  font-size: 0.875rem;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  font-weight: 500;
  color: var(--bs-body-color);
  background-color: var(--bs-body-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: 0.375rem;
  box-shadow: inset 0 -1px 0 var(--bs-border-color);
  min-width: 1.5rem;
  text-align: center;
}
</style>
