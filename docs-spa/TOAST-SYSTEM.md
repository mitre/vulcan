# Vulcan SPA - Toast Notification System

## Overview

Vulcan uses Bootstrap-Vue-Next's toast system with a custom composable wrapper for convenience.

## Architecture

```
app/javascript/
├── composables/
│   ├── index.ts          # Re-exports
│   └── useToast.ts       # Toast composable wrapper
└── components/
    └── toaster/
        └── Toaster.vue   # Handles Rails flash messages
```

## Usage

### In Components (Composition API)

```typescript
import { useAppToast } from '@/composables'

// In setup()
const toast = useAppToast()

// Success
toast.success('Project created!')

// Error
toast.error('Failed to save changes')

// Warning
toast.warning('This action cannot be undone')

// Info
toast.info('New updates available')

// Custom options
toast.show('Custom message', {
  title: 'Custom Title',
  variant: 'primary',
  delay: 10000,
  pos: 'bottom-right'
})
```

### Handling API Responses

```typescript
const toast = useAppToast()

try {
  const response = await projectsStore.createProject(data)
  toast.fromResponse(response) // Shows success from { toast: "message" }
} catch (error) {
  toast.fromError(error) // Shows error message
}
```

### Rails Response Format

Controllers should return toast data in one of these formats:

```ruby
# String format (simple success)
render json: { toast: 'Successfully created project' }

# Object format (with variant)
render json: {
  toast: {
    title: 'Error',
    variant: 'danger',
    message: 'Could not save changes'
  }
}, status: :unprocessable_entity

# Array of messages
render json: {
  toast: {
    title: 'Validation Error',
    variant: 'danger',
    message: @model.errors.full_messages
  }
}, status: :unprocessable_entity
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | string | varies | Toast header title |
| `variant` | string | 'primary' | Bootstrap variant (success, danger, warning, info, etc.) |
| `autoHide` | boolean | true | Auto-dismiss after delay |
| `delay` | number | 5000 | Milliseconds before auto-hide |
| `solid` | boolean | true | Use solid background |
| `pos` | string | 'top-right' | Position on screen |

## Position Values

- `top-left`, `top-center`, `top-right`
- `middle-left`, `middle-center`, `middle-right`
- `bottom-left`, `bottom-center`, `bottom-right`

## Important Notes

1. **Must use in component setup**: `useAppToast()` requires Vue's composition API context
2. **BApp wrapper required**: App must be wrapped in `<BApp>` for toasts to work
3. **Errors stay longer**: Error toasts auto-hide after 8 seconds (vs 5 for success)

## Migration from AlertMixin

Old (Options API with mixin):
```javascript
export default {
  mixins: [AlertMixinVue],
  methods: {
    doSomething() {
      this.alertOrNotifyResponse(response)
    }
  }
}
```

New (Composition API):
```typescript
import { useAppToast } from '@/composables'

const toast = useAppToast()
toast.fromResponse(response)
```
