# Inertia.js: The Modern Rails + Vue Bridge
## Complete Guide for Vulcan Migration

## What is Inertia.js?

**Inertia is NOT:**
- ❌ An API layer
- ❌ A JavaScript framework
- ❌ A replacement for Rails
- ❌ A state management library

**Inertia IS:**
- ✅ A protocol for connecting backend + frontend
- ✅ A way to build SPAs without APIs
- ✅ Server-side routing with client-side rendering
- ✅ The "glue" between Rails and Vue/React/Svelte

**Think of it as:** "What if Rails controllers could render Vue components instead of ERB templates?"

---

## How Inertia Works

### Traditional Rails
```ruby
class RulesController < ApplicationController
  def index
    @rules = Rule.all
    render :index  # Renders views/rules/index.html.erb
  end
end
```

### Rails API + Vue SPA
```ruby
# Backend API
class Api::RulesController < ApplicationController
  def index
    render json: Rule.all
  end
end
```
```javascript
// Frontend Vue
const { data } = await axios.get('/api/rules')
this.rules = data
```

### Inertia.js Approach
```ruby
class RulesController < ApplicationController
  def index
    render inertia: 'Rules/Index', props: {
      rules: Rule.all,
      filters: params[:filters],
      can_edit: can?(:edit, Rule)
    }
  end
end
```
```vue
<!-- Pages/Rules/Index.vue -->
<script setup>
// Props automatically injected - no API call needed!
defineProps({
  rules: Array,
  filters: Object,
  can_edit: Boolean
})
</script>

<template>
  <div>
    <!-- Use props directly -->
    <UTable :rows="rules" />
  </div>
</template>
```

---

## Core Concepts

### 1. **Page Components Replace Views**
```
Traditional Rails:
app/views/rules/index.html.erb
app/views/rules/show.html.erb
app/views/rules/edit.html.erb

Inertia:
resources/js/Pages/Rules/Index.vue
resources/js/Pages/Rules/Show.vue
resources/js/Pages/Rules/Edit.vue
```

### 2. **Props Replace Instance Variables**
```ruby
# Traditional
def show
  @rule = Rule.find(params[:id])
  @comments = @rule.comments
end

# Inertia
def show
  rule = Rule.find(params[:id])
  render inertia: 'Rules/Show', props: {
    rule: rule.as_json(include: :comments),
    current_user: current_user.slice(:id, :name, :role)
  }
end
```

### 3. **Forms Work Like Rails (But Better)**
```vue
<script setup>
import { useForm } from '@inertiajs/vue3'

const form = useForm({
  name: '',
  description: '',
  severity: 'medium'
})

const submit = () => {
  form.post('/rules', {
    onSuccess: () => form.reset()
  })
}
</script>

<template>
  <form @submit.prevent="submit">
    <UInput v-model="form.name" :error="form.errors.name" />
    <UTextarea v-model="form.description" />
    <UButton type="submit" :loading="form.processing">
      Create Rule
    </UButton>
  </form>
</template>
```

Rails controller stays familiar:
```ruby
def create
  @rule = Rule.new(rule_params)

  if @rule.save
    redirect_to rules_path, notice: 'Rule created!'
  else
    redirect_back fallback_location: rules_path,
                  inertia: { errors: @rule.errors }
  end
end
```

---

## Real Vulcan Migration Example

### Current Vulcan (Vue 2 + Webpacker + API calls)

```vue
<!-- components/RuleEditor.vue -->
<template>
  <div>
    <b-modal v-model="showModal">
      <b-form @submit="saveRule">
        <b-form-input v-model="rule.name" />
      </b-form>
    </b-modal>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  data() {
    return {
      rule: {},
      showModal: false
    }
  },
  async mounted() {
    const { data } = await axios.get(`/api/rules/${this.$route.params.id}`)
    this.rule = data
  },
  methods: {
    async saveRule() {
      await axios.put(`/api/rules/${this.rule.id}`, this.rule)
      this.$router.push('/rules')
    }
  }
}
</script>
```

### New Version (Inertia + Vue 3 + NuxtUI)

```vue
<!-- Pages/Rules/Edit.vue -->
<script setup>
import { useForm } from '@inertiajs/vue3'

// Props from Rails controller - no API call!
const props = defineProps({
  rule: Object,
  projects: Array,
  can_delete: Boolean
})

// Inertia's form helper - handles submission, errors, loading
const form = useForm({
  name: props.rule.name,
  description: props.rule.description,
  severity: props.rule.severity,
  project_id: props.rule.project_id
})

const submit = () => {
  form.put(`/rules/${props.rule.id}`)
}
</script>

<template>
  <UCard>
    <template #header>
      <h3>Edit Rule: {{ rule.name }}</h3>
    </template>

    <UForm :state="form" @submit="submit">
      <UFormGroup label="Name" :error="form.errors.name">
        <UInput v-model="form.name" />
      </UFormGroup>

      <UFormGroup label="Project">
        <USelectMenu
          v-model="form.project_id"
          :options="projects"
          option-attribute="name"
          value-attribute="id"
        />
      </UFormGroup>

      <UButton type="submit" :loading="form.processing">
        Save Changes
      </UButton>
    </UForm>
  </UCard>
</template>
```

```ruby
# app/controllers/rules_controller.rb
class RulesController < ApplicationController
  def edit
    @rule = Rule.find(params[:id])

    render inertia: 'Rules/Edit', props: {
      rule: @rule,
      projects: Project.select(:id, :name),
      can_delete: can?(:destroy, @rule)
    }
  end

  def update
    @rule = Rule.find(params[:id])

    if @rule.update(rule_params)
      redirect_to rule_path(@rule), notice: 'Rule updated successfully'
    else
      redirect_back fallback_location: edit_rule_path(@rule),
                    inertia: { errors: @rule.errors }
    end
  end
end
```

---

## Key Benefits for Vulcan

### 1. **No More API Controllers**
```ruby
# DELETE these:
app/controllers/api/rules_controller.rb
app/controllers/api/projects_controller.rb
app/controllers/api/users_controller.rb

# Just use regular controllers!
app/controllers/rules_controller.rb  # Serves both HTML and Inertia
```

### 2. **Authentication Just Works**
```ruby
# Devise/authentication works exactly the same
class RulesController < ApplicationController
  before_action :authenticate_user!  # Still works!

  def index
    # current_user available as normal
    render inertia: 'Rules/Index', props: {
      rules: current_user.rules,
      user: current_user.slice(:id, :name, :role)
    }
  end
end
```

### 3. **File Uploads Stay Simple**
```vue
<script setup>
import { useForm } from '@inertiajs/vue3'

const form = useForm({
  title: '',
  stig_file: null
})

const submit = () => {
  // Inertia handles multipart/form-data automatically
  form.post('/stigs/import')
}
</script>

<template>
  <UFormGroup label="Import STIG">
    <UInput
      type="file"
      @change="form.stig_file = $event.target.files[0]"
    />
  </UFormGroup>
</template>
```

### 4. **Validation Stays Server-Side**
```ruby
# Models/validations unchanged
class Rule < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :severity, inclusion: { in: %w[high medium low] }
end

# Controller just redirects with errors
def create
  @rule = Rule.new(rule_params)

  if @rule.save
    redirect_to rules_path
  else
    # Inertia automatically preserves form state
    redirect_back fallback_location: new_rule_path,
                  inertia: { errors: @rule.errors }
  end
end
```

---

## Advanced Features

### 1. **Partial Reloads** (Incredible Performance)
```vue
<script setup>
import { router } from '@inertiajs/vue3'

// Only reload the 'rules' prop, not entire page
const refreshRules = () => {
  router.reload({ only: ['rules'] })
}

// Load additional data on demand
const loadStats = () => {
  router.reload({
    only: ['stats'],
    onSuccess: () => console.log('Stats loaded')
  })
}
</script>
```

### 2. **Shared Data** (Layout Props)
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  inertia_share do
    {
      auth: {
        user: current_user&.slice(:id, :name, :email, :role)
      },
      flash: flash.to_hash,
      errors: flash[:errors],
      # Shared across ALL pages
      app_version: Rails.application.config.version
    }
  end
end
```

```vue
<!-- Accessible in any component -->
<script setup>
import { usePage } from '@inertiajs/vue3'

const page = usePage()
const user = computed(() => page.props.auth.user)
const flash = computed(() => page.props.flash)
</script>
```

### 3. **Lazy Loading Data**
```ruby
class DashboardController < ApplicationController
  def show
    render inertia: 'Dashboard', props: {
      # Load immediately
      projects: Project.limit(10),

      # Load only when component requests it
      stats: InertiaRails.lazy(-> {
        expensive_calculation
      }),

      # Load rules only if needed
      all_rules: InertiaRails.lazy(-> {
        Rule.includes(:project).all
      })
    }
  end
end
```

### 4. **Preserve Scroll Position**
```vue
<script setup>
import { Link } from '@inertiajs/vue3'
</script>

<template>
  <!-- Preserves scroll position when navigating back -->
  <Link href="/rules" preserve-scroll>
    View All Rules
  </Link>
</template>
```

---

## Setting Up Inertia in Rails 8

### Step 1: Install Dependencies
```bash
# Create new Rails 8 app
rails new vulcan2 -d postgresql -j esbuild -c tailwind

# Add Inertia gem
bundle add inertia_rails

# Install Vue and Inertia npm packages
npm install @inertiajs/vue3 vue@latest @nuxt/ui
```

### Step 2: Configure Rails
```ruby
# config/initializers/inertia_rails.rb
InertiaRails.configure do |config|
  config.version = '1.0'

  # Specify where page components live
  config.component_path = 'Pages'

  # Use deep merge for shared data
  config.deep_merge_shared_data = true
end
```

### Step 3: Setup Application Layout
```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_include_tag "application", "data-turbo-track": "reload", type: "module" %>

    <!-- Inertia needs this -->
    <%= inertia_headers %>
  </head>
  <body>
    <!-- Single mount point -->
    <%= inertia %>
  </body>
</html>
```

### Step 4: Create App Entry Point
```javascript
// app/javascript/application.js
import { createApp, h } from 'vue'
import { createInertiaApp } from '@inertiajs/vue3'
import NuxtUI from '@nuxt/ui'

createInertiaApp({
  resolve: name => {
    const pages = import.meta.glob('./Pages/**/*.vue', { eager: true })
    return pages[`./Pages/${name}.vue`]
  },
  setup({ el, App, props, plugin }) {
    createApp({ render: () => h(App, props) })
      .use(plugin)
      .use(NuxtUI)
      .mount(el)
  },
  progress: {
    color: '#4B5563',
  },
})
```

### Step 5: Create First Page Component
```vue
<!-- app/javascript/Pages/Dashboard.vue -->
<script setup>
import { Head } from '@inertiajs/vue3'

defineProps({
  projects: Array,
  rules_count: Number,
  recent_activity: Array
})
</script>

<template>
  <div>
    <Head title="Dashboard" />

    <UContainer>
      <UCard>
        <template #header>
          <h1>Vulcan Dashboard</h1>
        </template>

        <UStats>
          <UStat label="Projects" :value="projects.length" />
          <UStat label="Rules" :value="rules_count" />
        </UStats>

        <UTable :rows="recent_activity" />
      </UCard>
    </UContainer>
  </div>
</template>
```

### Step 6: Update Controller
```ruby
class DashboardController < ApplicationController
  def index
    render inertia: 'Dashboard', props: {
      projects: current_user.projects,
      rules_count: Rule.count,
      recent_activity: Activity.recent.limit(10)
    }
  end
end
```

---

## Gotchas and Solutions

### 1. **File Structure Change**
```
Before:
app/javascript/
├── packs/
│   └── application.js
└── components/
    └── RuleEditor.vue

After:
app/javascript/
├── application.js
├── Pages/
│   ├── Rules/
│   │   ├── Index.vue
│   │   └── Edit.vue
│   └── Dashboard.vue
└── Components/
    └── RuleCard.vue
```

### 2. **No More Turbo/Turbolinks**
```javascript
// Remove these
import Turbolinks from 'turbolinks'
Turbolinks.start()

// Inertia handles navigation now
```

### 3. **Flash Messages**
```ruby
# Controller - works normally
redirect_to rules_path, notice: 'Rule created!'

# Vue component - access via shared data
<template>
  <UAlert v-if="$page.props.flash.notice" color="green">
    {{ $page.props.flash.notice }}
  </UAlert>
</template>
```

### 4. **Background Jobs**
```ruby
# Still process jobs normally
class ProcessStigJob < ApplicationJob
  def perform(stig_id)
    # Process...

    # Broadcast updates (with Inertia)
    InertiaRails::Events.emit('stig:processed', stig_id)
  end
end
```

```vue
<script setup>
import { router } from '@inertiajs/vue3'

// Listen for server events
Echo.channel('stigs')
  .listen('StigProcessed', (e) => {
    // Refresh just the stigs data
    router.reload({ only: ['stigs'] })
  })
</script>
```

---

## Migration Strategy for Vulcan

### Phase 1: Setup (Week 1)
1. Create new Rails 8 app with Inertia
2. Copy models and migrations
3. Setup authentication (Devise works fine)
4. Create layout component

### Phase 2: Core Pages (Week 2-3)
```ruby
# Start with read-only pages
class RulesController < ApplicationController
  def index
    render inertia: 'Rules/Index', props: {
      rules: Rule.page(params[:page]),
      filters: filter_params
    }
  end
end
```

### Phase 3: Interactive Features (Week 4-5)
```vue
<!-- Add forms and interactions -->
<script setup>
import { useForm } from '@inertiajs/vue3'

const form = useForm({
  name: '',
  severity: 'medium'
})
</script>
```

### Phase 4: Complex Components (Week 6-7)
- Port rule editor
- Port component navigator
- Port review workflow

### Phase 5: Polish (Week 8)
- Add transitions
- Optimize queries
- Add lazy loading

---

## Why Inertia is Perfect for Vulcan

### ✅ Keeps Rails Conventions
- Routes stay the same
- Controllers stay familiar
- Validations unchanged
- Auth works as-is

### ✅ Modern Frontend
- Use Vue 3 + NuxtUI
- Full component library
- Composition API
- TypeScript support

### ✅ Simplified Architecture
- No API layer
- No state management needed
- No token auth
- No CORS issues

### ✅ Developer Experience
- Hot reload
- Vue DevTools work
- Rails debugging unchanged
- Single deployment

---

## Decision Time

### Inertia is PERFECT if you want:
- Rails backend + Vue frontend
- Keep using NuxtUI components
- Server-side routing
- Simple deployment
- No API maintenance

### Skip Inertia if you want:
- Pure Rails (use Hotwire)
- Separate frontend/backend teams
- Mobile app later (need API)
- Offline-first PWA
- GraphQL

For Vulcan's needs and your solo development, Inertia + Vue 3 + NuxtUI is the sweet spot between modern UI and Rails simplicity.

Want me to create a proof-of-concept Vulcan page using Inertia?