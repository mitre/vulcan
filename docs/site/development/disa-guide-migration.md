# DISA Vendor STIG Process Guide — Migration Runbook

How to update the guide when DISA releases a new version.

## Prerequisites

- **pandoc** (3.x+): `brew install pandoc` (macOS) or `apt install pandoc` (Linux/CI)

## Steps

### 1. Preview the conversion

Point the task at the downloaded document — it does not need to be copied
anywhere first:

```bash
bundle exec rake "docs:guide:convert[/path/to/U_Vendor_STIG_Process_Guide_V4R3.docx]" > /tmp/preview.md
```

Open `/tmp/preview.md` and verify:
- Page title and version/date are correct
- Headings are properly leveled (`##` for top-level sections)
- Tables render (may need manual cleanup for complex tables)
- No stale TOC or revision history blocks

### 2. Run the full update pipeline

```bash
bundle exec rake "docs:guide:update[/path/to/U_Vendor_STIG_Process_Guide_V4R3.docx]"
```

This will:
1. Convert the .docx to cleaned markdown
2. Write `docs/site/disa-process/vendor-stig-process-guide.md`
3. Copy the .docx into `docs/site/public/attachments/` — the single home for
   downloadable attachments, published verbatim by the site build

### 3. Update references

These files reference the guide version and must be updated manually:

| File | What to update |
|------|---------------|
| `docs/site/disa-process/overview.md` | Version in source citations + reference table |
| `docs/site/disa-process/field-requirements.md` | Version reference in intro paragraph |
| `app/services/export/modes/vendor_submission.rb` | Comment referencing guide version |
| `app/models/rule.rb` | Comment referencing guide version (if section numbers changed) |

### 4. Remove the old .docx

```bash
rm docs/site/public/attachments/U_Vendor_STIG_Process_Guide_V4R1_20220815.docx
```

### 5. Verify

```bash
# Preview the documentation site
yarn openapi:docs
cd docs && yarn dev
# Navigate to /disa-process/vendor-stig-process-guide

# Build check
cd docs && yarn build

# In-app: rebuild the served site, then visit /docs/disa-process/vendor-stig-process-guide
```

### 6. Review manually

After automated conversion, always check:

- **Tables**: Pandoc converts complex Word tables to markdown pipe tables. Wide tables may need manual column adjustment.
- **Images**: Pandoc extracts to `media/` by default. Move any extracted images to `docs/site/public/attachments/` and reference them root-absolute (`/attachments/<name>`), which every build target rebases correctly.
- **Callouts**: VitePress renders `::: info` / `::: warning` / `::: tip` containers natively. Add callouts for critical DISA guidance.
- **Field requirements**: If the new guide changed field requirements (Section 4), update `docs/site/disa-process/field-requirements.md` to match.
- **Section numbers**: If sections were renumbered, update code comments that reference specific sections (e.g., `V4R1 §4.1.15`).

## What the rake task does

1. Shells out to `pandoc` with flags:
   - `--wrap=none` — no line wrapping
   - `--shift-heading-level-by=1` — reserves `#` for page title
   - `--markdown-headings=atx` — consistent `#` style
2. Extracts version and date from document content
3. Prepends a standard header (title + version + download link)
4. Strips the TOC and revision history (useful in .docx, noise in markdown)
5. Cleans pandoc artifacts (`{.anchor}` attributes, empty link refs, excess blank lines)
