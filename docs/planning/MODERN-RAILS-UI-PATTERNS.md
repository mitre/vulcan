# Modern Rails UI Patterns Explained
## ViewComponents, Phlex, and Hotwire

## 1. Hotwire (HTML Over The Wire)
**What**: Rails' built-in solution for dynamic UIs without writing JavaScript
**Components**: Turbo + Stimulus
**Philosophy**: Send HTML from server instead of JSON

### Turbo Features

#### Turbo Drive (formerly Turbolinks)
```erb
<!-- Automatic SPA-like navigation -->
<%= link_to "View Project", project_path(@project) %>
<!-- Page loads without full refresh -->
```

#### Turbo Frames
```erb
<!-- Replace parts of page without JavaScript -->
<div id="rule_editor">
  <%= turbo_frame_tag "rule_form" do %>
    <%= form_with model: @rule do |f| %>
      <%= f.text_field :name %>
      <%= f.submit %>
    <% end %>
  <% end %>
</div>

<!-- Clicking submit only updates the frame, not whole page -->
```

#### Turbo Streams
```erb
<!-- Real-time updates without WebSockets code -->
<!-- app/views/rules/create.turbo_stream.erb -->
<%= turbo_stream.append "rules_list" do %>
  <%= render @rule %>
<% end %>

<%= turbo_stream.update "rules_count" do %>
  Total: <%= @rules.count %>
<% end %>
```

### Stimulus (Lightweight JS)
```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  
  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
}
```

```erb
<!-- Use in HTML -->
<div data-controller="dropdown">
  <button data-action="click->dropdown#toggle">Menu</button>
  <div data-dropdown-target="menu" class="hidden">
    <!-- menu items -->
  </div>
</div>
```

### Hotwire vs Vue.js for Vulcan

**Current Vue Component** (Complex):
```vue
<template>
  <div>
    <button @click="showModal = true">Edit Rule</button>
    <modal v-if="showModal">
      <rule-form 
        :rule="rule" 
        @save="handleSave"
        @cancel="showModal = false"
      />
    </modal>
  </div>
</template>

<script>
export default {
  data() {
    return { showModal: false, rule: {} }
  },
  methods: {
    async handleSave(data) {
      const response = await axios.post('/rules', data)
      this.rules.push(response.data)
      this.showModal = false
    }
  }
}
</script>
```

**Hotwire Equivalent** (Simpler):
```erb
<!-- app/views/rules/index.html.erb -->
<%= turbo_frame_tag "rule_modal" %>
<%= link_to "Edit Rule", edit_rule_path(@rule), 
    data: { turbo_frame: "rule_modal" } %>

<!-- app/views/rules/edit.html.erb -->
<%= turbo_frame_tag "rule_modal" do %>
  <div class="modal">
    <%= form_with model: @rule do |f| %>
      <%= f.text_field :name %>
      <%= f.submit %>
      <%= link_to "Cancel", rules_path, 
          data: { turbo_frame: "_top" } %>
    <% end %>
  </div>
<% end %>
```

**No JavaScript needed!** Rails handles the modal show/hide and form submission.

---

## 2. ViewComponent (GitHub's Component System)
**What**: Ruby objects that encapsulate view logic
**Why**: Testable, reusable, performant components
**By**: GitHub (they use it in production)

### Traditional Rails Partial
```erb
<!-- app/views/shared/_rule_card.html.erb -->
<div class="card <%= 'disabled' if rule.disabled? %>">
  <h3><%= rule.title %></h3>
  <p>Status: <%= rule.status_label %></p>
  <% if can?(:edit, rule) %>
    <%= link_to "Edit", edit_rule_path(rule) %>
  <% end %>
</div>

<!-- Usage -->
<%= render "shared/rule_card", rule: @rule %>
```

### ViewComponent Version
```ruby
# app/components/rule_card_component.rb
class RuleCardComponent < ViewComponent::Base
  def initialize(rule:, current_user:)
    @rule = rule
    @current_user = current_user
  end

  private

  attr_reader :rule, :current_user

  def status_class
    rule.disabled? ? "disabled" : "active"
  end

  def can_edit?
    current_user.can_edit?(rule)
  end

  def status_label
    rule.status.humanize
  end
end
```

```erb
<!-- app/components/rule_card_component.html.erb -->
<div class="card <%= status_class %>">
  <h3><%= rule.title %></h3>
  <p>Status: <%= status_label %></p>
  <% if can_edit? %>
    <%= link_to "Edit", edit_rule_path(rule) %>
  <% end %>
</div>
```

```erb
<!-- Usage -->
<%= render RuleCardComponent.new(rule: @rule, current_user: current_user) %>
```

### Why ViewComponent is Better

1. **Testable**:
```ruby
# test/components/rule_card_component_test.rb
class RuleCardComponentTest < ViewComponent::TestCase
  def test_renders_edit_link_for_authorized_user
    rule = create(:rule)
    user = create(:admin)
    
    render_inline(RuleCardComponent.new(rule: rule, current_user: user))
    
    assert_selector "a", text: "Edit"
  end
end
```

2. **Encapsulated**: All logic in one Ruby class
3. **Fast**: ~10x faster than partials
4. **Type-safe**: Can use Sorbet/RBS for typing

---

## 3. Phlex (Pure Ruby Views)
**What**: Write HTML in pure Ruby (no ERB templates)
**Why**: Type-safe, incredibly fast, composable
**Philosophy**: Views are just Ruby objects

### Phlex Component Example
```ruby
# app/views/components/rule_card.rb
class Components::RuleCard < Phlex::HTML
  def initialize(rule:)
    @rule = rule
  end

  def template
    div(class: card_classes) do
      h3 { @rule.title }
      
      p(class: "status") do
        plain "Status: "
        span(class: status_color) { @rule.status }
      end
      
      if @rule.editable?
        a(href: edit_rule_path(@rule), class: "btn btn-primary") { "Edit" }
      end
    end
  end

  private

  def card_classes
    classes = ["card"]
    classes << "disabled" if @rule.disabled?
    classes.join(" ")
  end

  def status_color
    case @rule.status
    when "active" then "text-green-500"
    when "pending" then "text-yellow-500"
    else "text-gray-500"
    end
  end
end
```

```ruby
# Usage in controller
class RulesController < ApplicationController
  def show
    @rule = Rule.find(params[:id])
    render Components::RuleCard.new(rule: @rule)
  end
end
```

### Phlex Composition (Powerful!)
```ruby
class Components::RulesList < Phlex::HTML
  def initialize(rules:)
    @rules = rules
  end

  def template
    div(class: "rules-grid") do
      @rules.each do |rule|
        # Compose components!
        render Components::RuleCard.new(rule: rule)
      end
    end
  end
end

class Components::Dashboard < Phlex::HTML
  def initialize(project:)
    @project = project
  end

  def template
    div(class: "dashboard") do
      h1 { @project.name }
      
      # Nest components naturally
      render Components::RulesList.new(rules: @project.rules)
      render Components::ProjectStats.new(project: @project)
    end
  end
end
```

---

## Comparison for Vulcan Migration

### Current Vue.js Approach
```vue
<!-- 72 .vue files with complex state management -->
<template>
  <div class="rule-editor">
    <input v-model="rule.name" @change="updateRule">
    <nested-component :data="rule.nested" />
  </div>
</template>

<script>
import axios from 'axios'
export default {
  data() { return { rule: {} } },
  methods: {
    async updateRule() {
      await axios.put(`/rules/${this.rule.id}`, this.rule)
    }
  }
}
</script>
```

### Option 1: Hotwire (Simplest)
```erb
<%= turbo_frame_tag dom_id(@rule) do %>
  <%= form_with model: @rule, data: { turbo_frame: "_self" } do |f| %>
    <%= f.text_field :name %>
    <!-- Auto-submits and updates without JS -->
  <% end %>
<% end %>
```
**Pros**: No JavaScript, works immediately
**Cons**: Less interactive than Vue

### Option 2: ViewComponent + Stimulus
```ruby
class RuleEditorComponent < ViewComponent::Base
  def initialize(rule:)
    @rule = rule
  end
end
```
```erb
<div data-controller="rule-editor">
  <%= form_with model: @rule do |f| %>
    <%= f.text_field :name, data: { action: "input->rule-editor#update" } %>
  <% end %>
</div>
```
**Pros**: Organized, testable, some interactivity
**Cons**: Need to learn new pattern

### Option 3: Phlex + Hotwire
```ruby
class RuleEditor < Phlex::HTML
  def template
    turbo_frame_tag dom_id(@rule) do
      form_with model: @rule do |f|
        f.text_field :name
      end
    end
  end
end
```
**Pros**: Type-safe, fast, no templates
**Cons**: Very different from current approach

---

## Recommendation for Vulcan

### Use Hotwire for 80% of UI
Perfect for:
- Forms and CRUD operations
- Navigation and page updates
- Filters and search
- Status updates
- Basic modals and dropdowns

### Keep Vue 3 for 20% Complex UI
Reserve for:
- Rule editor with live preview
- Complex component tree navigator
- Drag-and-drop interfaces
- Real-time collaborative features
- Rich text editors

### Example Migration Strategy

**Week 1-2: Replace simple interactions with Hotwire**
```ruby
# Before: Vue component for project list
# After: Turbo frame with server-side filtering
<%= turbo_frame_tag "projects_list" do %>
  <%= form_with url: projects_path, method: :get,
      data: { turbo_frame: "projects_list", turbo_action: "advance" } do |f| %>
    <%= f.text_field :search, value: params[:search],
        data: { action: "input->debounce#search" } %>
  <% end %>
  
  <div class="projects">
    <%= render @projects %>
  </div>
<% end %>
```

**Week 3-4: Add ViewComponents for complex partials**
```ruby
# Replace messy partials with components
class StigRuleComponent < ViewComponent::Base
  def initialize(rule:, show_actions: true)
    @rule = rule
    @show_actions = show_actions
  end
  
  def severity_badge
    content_tag :span, @rule.severity,
      class: "badge badge-#{severity_color}"
  end
  
  private
  
  def severity_color
    { high: "danger", medium: "warning", low: "info" }[@rule.severity.to_sym]
  end
end
```

**Week 5+: Vue 3 only for truly complex components**
```javascript
// Keep Vue for the complex rule relationship editor
import { createApp } from 'vue'
import RuleRelationshipEditor from './components/RuleRelationshipEditor.vue'

// Mount only where needed
document.addEventListener('turbo:load', () => {
  const el = document.getElementById('rule-relationship-editor')
  if (el) {
    createApp(RuleRelationshipEditor, {
      ruleId: el.dataset.ruleId
    }).mount(el)
  }
})
```

---

## Cost/Benefit for Solo Developer

### Pure Hotwire Approach
**Time**: -60% development time
**Complexity**: -80% less JavaScript
**Performance**: +50% faster (server rendering)
**Maintenance**: Much simpler

### Hybrid (Hotwire + Vue for complex)
**Time**: -40% development time  
**Complexity**: -60% less JavaScript
**Performance**: +30% faster
**Maintenance**: Best of both worlds

### Decision Helper

Use **Hotwire** when:
- Form submissions
- Page navigation  
- Content updates
- Filters/search
- Simple interactions

Use **Vue 3** when:
- Complex state management
- Rich interactions
- Offline capability needed
- Real-time collaboration
- Canvas/graphics

Use **ViewComponent/Phlex** when:
- Reusable UI patterns
- Complex view logic
- Need testing
- Performance critical

---

## Quick Hotwire Demo for Vulcan

Transform this Vue component:
```vue
<!-- ProjectSelector.vue -->
<template>
  <div>
    <select v-model="selected" @change="loadComponents">
      <option v-for="p in projects" :value="p.id">{{ p.name }}</option>
    </select>
    <div v-if="loading">Loading...</div>
    <ul v-else>
      <li v-for="c in components">{{ c.name }}</li>
    </ul>
  </div>
</template>
```

Into this Hotwire version:
```erb
<!-- No JavaScript needed! -->
<%= form_with url: project_components_path, method: :get,
    data: { turbo_frame: "components" } do |f| %>
  <%= f.select :project_id, options_from_collection_for_select(@projects, :id, :name),
      { prompt: "Select Project" },
      { data: { action: "change->form#requestSubmit" } } %>
<% end %>

<%= turbo_frame_tag "components", loading: :lazy do %>
  <!-- Automatically shows loading state -->
  <div>Loading components...</div>
<% end %>
```

The Hotwire version is simpler, requires no build step, and is easier to maintain!