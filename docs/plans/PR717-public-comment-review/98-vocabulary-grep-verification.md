# Task 98: Vocabulary grep verification (run before EVERY commit)

**Depends on:** —
**Estimate:** < 1 min Claude-pace per run
**Not a TDD task** — a pre-commit guard-rail per design §3.1.1 / §7.1.

This is a checklist of greps the agent runs before each commit. They take 2 seconds and catch the most common drift between the storage layer (DISA-native) and the UI layer (friendly English).

If any check produces unexpected output, **STOP and surface to the user**. Don't paper over.

---

## The five checks

### (a) DISA terms in user-facing templates

DISA terms (`concur`, `non_concur`, `adjudicat*`) should NOT appear in Vue components or HAML views, with three intentional exceptions:
1. `app/javascript/constants/triageVocabulary.js` (the canonical mapping file)
2. `config/locales/en.yml` (the i18n source)
3. `app/javascript/components/components/CommentTriageModal.vue` (the pedagogical exception — radio labels show "Accept (Concur)")

```bash
grep -rnE "concur|adjudicat|non.concur" \
  app/javascript/components app/views \
  | grep -v triageVocabulary \
  | grep -v locales/en.yml \
  | grep -v CommentTriageModal \
  | grep -v "triage-status--"  # CSS class hooks use stable DISA keys — fine
```

**Expected:** zero output. Each match must be either fixed or annotated with an inline comment justifying why the exception is intentional.

### (b) Friendly UI labels in DB / migration / model / controller / API code

Friendly UI labels (`accept`, `decline`, `closed`) should NOT appear as quoted strings in backend code. The DB stores DISA keys; controllers respond with DISA keys.

```bash
grep -rnE "\"(accept|decline|closed)\"" app/models app/controllers db/migrate
```

**Expected:** zero output. (Excludes inline comments — only matches actual string literals.)

### (c) Parity between en.yml and triageVocabulary.js

```bash
ruby -ryaml -e '
  yml = YAML.load_file("config/locales/en.yml").dig("en", "vulcan", "triage", "status")
  js  = File.read("app/javascript/constants/triageVocabulary.js")
  yml.each_key do |k|
    abort "ERROR: #{k} is in en.yml but not in TRIAGE_LABELS in JS" unless js.include?("#{k}:")
  end
  puts "OK"
'
```

**Expected:** prints `OK`.

### (d) CSS / DOM hooks use stable DISA keys, not friendly labels

```bash
grep -rnE 'class="[^"]*triage-status--(accept|decline|closed)' \
  app/javascript app/views
```

**Expected:** zero output. CSS classes should be `triage-status--concur`, `triage-status--non_concur`, etc.

### (e) i18n coverage — every status has a label

```bash
ruby -ryaml -e '
  expected = %w[pending concur concur_with_comment non_concur duplicate
                informational needs_clarification withdrawn]
  yml = YAML.load_file("config/locales/en.yml").dig("en", "vulcan", "triage", "status")
  missing = expected - yml.keys
  abort "ERROR: missing labels: #{missing}" if missing.any?
  puts "OK"
'
```

**Expected:** prints `OK`.

---

## Run all five at once

```bash
docs/plans/PR717-public-comment-review/run_vocabulary_checks.sh
```

(Optionally create that script — wraps the five grep/ruby invocations and exits non-zero if any fail. Useful to wire into a pre-commit hook.)

If any check fails: **DO NOT COMMIT.** Fix the drift, re-run all five, then commit.

---

## When to add this to lefthook / pre-commit

Once Task 99 has run successfully and the implementation is green, consider adding the script to `.lefthook.yml` under `pre-commit`:

```yaml
pre-commit:
  commands:
    triage_vocabulary:
      run: docs/plans/PR717-public-comment-review/run_vocabulary_checks.sh
      glob: "{app,config,spec}/**/*"
```

This catches drift on the next PR that touches any of these files, not just this one.
