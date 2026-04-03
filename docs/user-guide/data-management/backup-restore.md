# Backup & Restore

Vulcan's backup and restore system lets you create full-fidelity archives of projects and restore them — on the same instance or a different one. Backups preserve all component data, rules, reviews, satisfaction relationships, and optionally project memberships.

## Backup Format

Backups use **JSON Archive** format — a ZIP file containing:

```
project-name-backup.zip
├── manifest.json              # Archive metadata + component list
├── project.json               # Project name, description, visibility
├── component-name/
│   ├── component.json         # Component fields (name, prefix, version, etc.)
│   ├── rules.json             # All rules with full field data
│   ├── satisfactions.json     # Rule satisfaction relationships
│   └── reviews.json           # Review history (optional)
└── component-name-2/
    └── ...
```

Every field is preserved exactly as stored in the database. No lossy format conversion.

## Creating a Backup

1. Navigate to the **Project** page
2. Click the **Export** button
3. Select **Backup** as the purpose
4. **JSON Archive** format is auto-selected
5. Optionally check **Include project memberships**
6. Select which components to include (or all)
7. Click **Export**

The browser downloads a `.zip` file.

::: tip Include Memberships
When checked, backup includes a `memberships.json` file listing each member's email and role. On restore, existing users are matched by email and granted the same roles. Users not found on the target instance are skipped.
:::

## Restoring Into an Existing Project

Use this to add components from a backup into a project that already exists.

1. Navigate to the **Project** page
2. Click **New Component**
3. Select **Restore From Backup**
4. Upload the ZIP file
5. Choose whether to include reviews and memberships
6. Click **Preview** to see what will be imported

### Component Selection

The preview step shows each component from the archive with its rule count:

| Component | Rules | Status |
|-----------|-------|--------|
| Photon OS 4 | 203 | Ready to import |
| Windows Server 2025 | 275 | Name conflict — auto-renamed |

- **No conflict**: Checked by default, imports as-is
- **Name conflict**: Component name already exists in the project. Auto-renamed with "(restored)" suffix. You can edit the name inline before importing.
- Uncheck any component you don't want to import

Click **Import** to proceed with the selected components.

## Creating a New Project from Backup

Use this to clone or migrate a project to a new instance.

1. Navigate to **Projects** on the main page
2. Click the **New Project** dropdown arrow
3. Select **From Backup**
4. Upload the ZIP file
5. Edit the project name, description, and visibility (pre-filled from the archive)
6. Choose whether to include reviews and memberships
7. Click **Preview** to see the summary
8. Click **Create Project**

Vulcan creates a new project, imports all components, and redirects you to the new project page.

::: info Name Conflicts
If a project with the same name already exists, the name is pre-filled with a "(restored)" suffix. You can change it to anything before creating.
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
| Reviews and review history | Optional | Optional |
| Project memberships | Optional | Optional (matched by email) |
| SRG association | By SRG ID | Matched to existing SRG on target |

::: warning SRG Requirement
The target instance must have the same SRGs loaded. If a component references an SRG that doesn't exist on the target, the import will fail with an error identifying the missing SRG.
:::

## Use Cases

- **Migration**: Move projects between Vulcan instances (dev → staging → production)
- **Disaster recovery**: Restore from a backup after data loss
- **Cloning**: Create a copy of a project to start a new version
- **Sharing**: Send a project archive to another team running their own Vulcan instance
- **Selective restore**: Import only specific components from a multi-component backup
