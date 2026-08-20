# HAML → Vue Serialization Standard

Every HAML template that passes data to a Vue component follows two rules:

1. **Model data goes through a Blueprint** — never hand-build hashes from ActiveRecord objects.
2. **Primitives use `.to_json` directly** — booleans, strings, integers, Settings values.

## Allowed Patterns

### Blueprint for model data

```haml
-# CORRECT: Blueprint serializes with a defined view
%Project{ 'v-bind:initial-project-state': ProjectBlueprint.render(@project, view: :show) }

-# CORRECT: Blueprint pre-serialized in controller
= javascript_include_tag 'users'
%Users{ 'v-bind:users' => users_json.to_json }
```

### `.to_json` for primitives

```haml
-# CORRECT: primitive values
'v-bind:signed_in': user_signed_in?.to_json,
'v-bind:current_user_id': current_user.id.to_json,
'v-bind:app_version': Vulcan::VERSION.to_json,
'v-bind:password-policy': Settings.password.to_json,
```

### `common_vue_props` helper for shared props

```haml
-# CORRECT: DRY shared props via VuePropsHelper
%ProjectComponent{ **common_vue_props,
  'v-bind:initial-component-state': @component_json,
  'v-bind:project': @project_json,
}
```

The `common_vue_props` helper centralizes `current_user_id`, `statuses`, and
`available_roles`. Adding a new shared prop requires changing one file
(`app/helpers/vue_props_helper.rb`), not every HAML template.

## Prohibited Patterns

```haml
-# WRONG: hand-built hash from AR object
'v-bind:user': { id: current_user.id, name: current_user.name, email: current_user.email }.to_json

-# WRONG: .as_json on AR object (uncontrolled field set)
'v-bind:component': @component.as_json.to_json

-# WRONG: .slice on AR object (fragile subset)
'v-bind:user': current_user.slice(:id, :name, :email).to_json

-# WRONG: copy-pasting the same prop across multiple HAML files
-# Use common_vue_props helper instead
```

## Static Route Data (the one exception)

`@navigation` in the application layout is a hand-built array of route hashes.
This is intentional — it's static config, not AR model data. It does not need a
Blueprint.

## Blueprints in Use

| Blueprint | HAML consumer | View |
|-----------|--------------|------|
| `UserBlueprint` | application layout, profile, users index | default, `:profile`, `:admin` |
| `ProjectIndexBlueprint` | projects index | default |
| `ProjectBlueprint` | rules index, component show | default |
| `ProjectAccessRequestBlueprint` | application layout | default |
| `ComponentBlueprint` | component show (via controller `@component_json`) | `:editor` |
| `VuePropsHelper` | component show, project show, rules index | n/a (helper) |

## SPA Migration Path

Blueprints are the bridge between HAML props and future API endpoints. When a
page migrates to the SPA:

1. The HAML template is removed
2. The Vue component fetches data from the API endpoint
3. The API endpoint renders the same Blueprint with the same view
4. The Vue component receives identical data — zero frontend changes

This is why every model data path must go through a Blueprint today. A hand-built
hash in HAML has no API equivalent — the SPA would need a new serializer.

## Audit Results (2026-06-15)

All HAML files audited. Zero hand-built AR model hashes remain:

- `components/show.html.haml` — `common_vue_props` + Blueprint `@component_json`
- `projects/show.html.haml` — `common_vue_props` + Blueprint `@project_json`
- `rules/index.html.haml` — `common_vue_props` + Blueprint renders
- `projects/index.html.haml` — `ProjectIndexBlueprint.render_as_json`
- `users/index.html.haml` — `UserBlueprint.render_as_json`
- `registrations/edit.html.haml` — `UserBlueprint.render(:profile)`
- `application.html.haml` — `UserBlueprint` + `ProjectAccessRequestBlueprint` + primitives
- `components/triage.html.haml` — Blueprint `@initial_state_json` + primitive
- `components/settings.html.haml` — Blueprint `@initial_state_json` + primitive
- `projects/triage.html.haml` — Blueprint `@initial_state_json` + primitive
