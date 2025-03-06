# Asset Pack Tags Migration Inventory

This file lists all templates using asset pack tags that need to be migrated.

## javascript_pack_tag

| File | Line Numbers | Entry Points |
|------|--------------|-------------|
| /app/views/components/index.html.haml | 2 | project_components |
| /app/views/components/show.html.haml | 2 | project_component |
| /app/views/projects/index.html.haml | 2 | projects |
| /app/views/projects/new.html.haml | 2 | new_project |
| /app/views/projects/show.html.haml | 2 | project |
| /app/views/rules/index.html.haml | 2 | rules |
| /app/views/security_requirements_guides/index.html.haml | 2 | security_requirements_guides |
| /app/views/stigs/index.html.haml | 2 | stigs |
| /app/views/stigs/show.html.haml | 2 | stig |
| /app/views/users/index.html.haml | 2 | users |

## stylesheet_pack_tag

| File | Line Numbers | Entry Points |
|------|--------------|-------------|
| /app/views/components/index.html.haml | 3 | project_components |
| /app/views/components/show.html.haml | 3 | project_component |
| /app/views/projects/index.html.haml | 3 | projects |
| /app/views/projects/new.html.haml | 3 | new_project |
| /app/views/projects/show.html.haml | 3 | project |
| /app/views/rules/index.html.haml | 3 | rules |
| /app/views/stigs/show.html.haml | 3 | project_component |

## image_pack_tag

No occurrences found.

## Migration Plan

### Entry Point Mapping

| Webpacker Entry Point | Migrated Entry Point | Status |
|----------------------|---------------------|--------|
| new_project | app/javascript/new_project.js | ❌ |
| project | app/javascript/project.js | ❌ |
| project_component | app/javascript/project_component.js | ❌ |
| project_components | app/javascript/project_components.js | ❌ |
| projects | app/javascript/projects.js | ❌ |
| rules | app/javascript/rules.js | ❌ |
| security_requirements_guides | app/javascript/security_requirements_guides.js | ❌ |
| stig | app/javascript/stig.js | ❌ |
| stigs | app/javascript/stigs.js | ❌ |
| users | app/javascript/users.js | ❌ |
