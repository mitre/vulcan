# Backup & Restore

Vulcan's backup and restore system lets you create full-fidelity archives of projects and restore them — on the same instance or a different one. Backups preserve all component data, rules, reviews, satisfaction relationships, and optionally project memberships.

## Backup Format

Backups use **JSON Archive** format — a ZIP file containing:

```
project-name-backup.zip
├── manifest.json                      # Archive metadata + component list
├── project.json                       # Project name, description, visibility,
│                                      #   metadata and memberships
├── components/
│   ├── Component-Name-V1R2/
│   │   ├── component.json             # Component fields (name, prefix, version, …)
│   │   ├── rules.json                 # All rules with full field data
│   │   ├── satisfactions.json         # Rule satisfaction relationships
│   │   └── reviews.json               # Review history
│   └── Another-Component-V1R1/
│       └── ...
└── srgs/                              # Base SRG XML, when Include base SRGs is on
    └── General_Purpose_Operating_System-V3R3.xml
```

A single-component export skips the `components/` level and puts the four
JSON files at the archive root.

Every field is preserved exactly as stored in the database. No lossy format conversion.

## Creating a Backup

1. Navigate to the **Project** page
2. Click the **Download** button
3. Select **Backup** as the purpose
4. **JSON Archive** format is auto-selected
5. Leave **Include base SRGs** checked (the default) if the archive may be
   restored on another instance — it bundles each component's source SRG XML
   so the target does not need those SRGs already loaded
6. Select which components to include (or all)
7. Click **Export**

The browser downloads a `.zip` file.

::: tip Memberships
Every archive carries the project's memberships inside `project.json`, as a
list of email, name and role — there is no separate `memberships.json`. On
restore you choose whether to apply them; existing users are matched by
email and granted the same role, and users not found on the target instance
are skipped.
:::

## Restoring Into an Existing Project

Use this to add components from a backup into a project that already exists.

1. Navigate to the **Project** page
2. Click **New Component**
3. Select **Restore From Backup**
4. Upload the ZIP file
5. Choose whether to include **review history** and **project memberships**
6. Click **Preview Import** to see what will be imported

### Component Selection

The preview step shows each component from the archive with its rule count:

Each row carries the component's name in an editable field, its rule count,
and a status marker:

- **Ready** — a green check. Checked by default, imports as-is.
- **`name taken`** — a component of that name already exists in the project.
  The name field is pre-filled with a "(restored)" suffix; edit it inline
  before importing.
- **`name required`** — you cleared the name field; fill it in to proceed.

Uncheck any component you don't want to import.

Click **Import** to proceed with the selected components.

## Creating a New Project from Backup

Use this to clone or migrate a project to a new instance.

1. Navigate to **Projects** on the main page
2. Click the **New Project** dropdown arrow
3. Select **From Backup**
4. Upload the ZIP file
5. Type a project name — **Preview** stays disabled until you do. The
   archive's own name shows as the field's placeholder.
6. Choose whether to include review history and project memberships
7. Click **Preview** to see the summary. Description and visibility are
   filled in from the archive at this point.
8. Click **Create Project**

Vulcan creates a new project, imports all components, and redirects you to the new project page.

::: info Project Names
Vulcan does not check the new project's name against existing projects and
does not rename it — two projects may share a name. The "(restored)" suffix
applies to *component* names inside an existing project, not to projects.
:::

## Export Pre-flight Warnings

When exporting in **DISA Vendor Submission** or **STIG-Ready Publish Draft** mode, Vulcan checks each component's rule statuses:

- Components where **all rules are "Not Yet Determined"** (NYD) get a warning icon in the component list
- If all selected components are NYD-only, a red alert warns that the export will produce empty output
- If some selected components are NYD-only, a yellow alert lists how many will produce empty worksheets

These modes exclude NYD rules from output (DISA does not accept NYD as a valid status), so exporting a component with only NYD rules produces nothing useful.

## What Gets Preserved

| Data | Backup | Restore |
|------|--------|---------|
| Component fields (name, prefix, version, title, etc.) | Yes | Yes |
| Rules (all fields including InSpec code) | Yes | Yes |
| Rule satisfaction relationships | Yes | Yes |
| Reviews and review history | Yes | Optional |
| Project memberships | Yes | Optional (matched by email) |
| SRG association | By SRG ID and version | Matched on the target, falling back to another release of the same SRG |

::: warning SRG Requirement
The target instance needs the component's base SRG. An archive exported with
**Include base SRGs** (the default) carries that XML and auto-imports it —
the preview says how many base SRGs it will add. Otherwise the target must
already have it: a different release of the same SRG will do, but if nothing
matches, the import fails with an error naming the missing SRG.
:::

## Use Cases

- **Migration**: Move projects between Vulcan instances (dev → staging → production)
- **Disaster recovery**: Restore from a backup after data loss
- **Cloning**: Create a copy of a project to start a new version
- **Sharing**: Send a project archive to another team running their own Vulcan instance
- **Selective restore**: Import only specific components from a multi-component backup
