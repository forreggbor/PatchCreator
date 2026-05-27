# PatchCreator — Usage Reference

## Options

| Flag | Argument | Default | Description |
|------|----------|---------|-------------|
| `-d` | `<path>` | Current directory | Project root directory |
| `-v` | `<version>` | Auto-detect | Target patch version |
| `-b` | `<git-ref>` | Last patch archive's commit, then latest tag | Base git reference to diff against |
| `-o` | `<dir>` | `<project>/storage/patch` | Output directory |
| `-r` | `<file>` | Auto from CHANGELOG.md | Release notes file |
| `-f` | `<file>` | — | File list override (one path per line) |
| `-e` | `<pattern>` | — | Exclude glob pattern (repeatable) |
| `-i` | `<pattern>` | — | Allow-override pattern — re-admits files matched by an exclude (repeatable) |
| `-p` | `<pattern>` | APP_VERSION define | Version detection regex |
| `--no-changelog` | — | — | Skip CHANGELOG.md extraction |
| `--dry-run` | — | — | Preview without creating archive |
| `--no-validate` | — | — | Skip PatchModule compatibility validation of the manifest |
| `--upload` | — | — | Force upload to LicenseManager even if auto-detection would skip it |
| `--no-upload` | — | — | Skip upload even if a configuration source is present |
| `-y` | — | — | Auto-confirm (skip prompts) |
| `-h` | — | — | Show help |
| `--version` | — | — | Show script version |

## Examples

### Auto-detect everything

```bash
PatchCreator.sh
```

Searches for `define('APP_VERSION', 'X.Y.Z')` across conventional file locations, diffs against the latest git tag, extracts release notes from `CHANGELOG.md`, and creates the archive in `storage/patch/`.

### Patch against a specific commit

```bash
PatchCreator.sh -b abc1234
```

### Dry run

```bash
PatchCreator.sh --dry-run
```

### Explicit version and base

```bash
PatchCreator.sh -v 2.33.0 -b v2.32.0
```

### Non-interactive (CI/CD)

```bash
PatchCreator.sh -v 2.33.0 -b v2.32.0 -y
```

### Explicit file list

```bash
PatchCreator.sh -v 2.33.0 -f patch_files.txt
```

`patch_files.txt` — one relative path per line:

```
app/helpers/functions.php
app/services/OrderService.php
public/js/common.js
```

### Exclude additional patterns

```bash
PatchCreator.sh -e "public/uploads/*" -e "*.tmp"
```

### Re-admit a specific vendor path

```bash
PatchCreator.sh -i "vendor/acme/"
```

### Specify a different project directory

```bash
PatchCreator.sh -d /var/www/myproject -o /tmp/patches
```

---

## Output

```
storage/patch/
├── patch-2.33.0.tgz
└── patch-2.33.0.tgz.sha256
```

### Archive contents

```
patch-2.33.0.tgz
├── manifest.json
├── migrations/                            (omitted when none)
│   └── 2026_05_11_151403_create_foo.sql
├── files/
│   ├── app/
│   ├── public/
│   └── ...
└── release_notes.md
```

### manifest.json

```json
{
    "version": "2.33.0",
    "built_from_commit": "a1b2c3d4...",
    "migrations": [
        "2026_05_11_151403_create_foo.sql"
    ],
    "files": [
        "app/helpers/functions.php",
        "public/js/common.js"
    ],
    "removed_files": [
        "app/legacy/OldService.php"
    ]
}
```

`migrations` is always present (empty array when none). `removed_files` is omitted when no files were deleted.

---

## SQL Migrations

Files matching `database/migrations/*.sql` in the git diff are automatically included in the `migrations/` directory — no flag needed. PatchModule v1.8.0+ executes them in lexicographic order.

- PHP migrations (`*.php`) are skipped with a warning.
- Files in subdirectories of `database/migrations/` are skipped with a warning.
- Deleted migration files are silently excluded from the archive.

> **Warning:** PatchModule's SQL parser strips both standard block comments (`/* ... */`) and MySQL conditional comments (`/*! ... */`). Do not rely on `/*! */` for version-gated SQL — rewrite as plain SQL or split into separate migrations.

---

## Version Auto-Detection

Searches for `define('APP_VERSION', 'X.Y.Z')` in these files, in order:

| Priority | Path |
|----------|------|
| 1 | `app/[Hh]elpers/functions.php` |
| 2 | `webroot/app/[Hh]elpers/functions.php` |
| 3 | `public/app/[Hh]elpers/functions.php` |

Use `-v` to specify the version explicitly, or `-p` to override the detection pattern.

---

## Default Exclude Patterns

| Pattern | Reason |
|---------|--------|
| `.git/`, `.gitignore`, `.gitattributes` | Version control |
| `storage/` | Runtime data |
| `vendor/`, `node_modules/` | Dependencies |
| `.env`, `.env.*` | Environment config |
| `*.log` | Log files |
| `CLAUDE.md`, `.claude/` | AI tooling |
| `package-lock.json` | Lock files |
| `tests/`, `phpunit.xml` | Test files |

`vendor/autoload.php` and `vendor/composer/` are re-admitted by default when they appear in the diff. Use `-i <pattern>` to re-admit other paths.

---

## Auto-Upload to LicenseManager

After a successful build, PatchCreator can POST the archive directly to LicenseManager's upload API.

### Configuration

**Option 1 — Environment variables (CI runners):**

```bash
export PATCHCREATOR_UPLOAD_URL="https://your-licensemanager.example.com/api/v1/patches/upload"
export PATCHCREATOR_TOKEN="lcmu_your_token_here"
```

**Option 2 — `.patchcreator.local` file in the project root (workstation):**

```json
{
  "upload_url": "https://your-licensemanager.example.com/api/v1/patches/upload",
  "token": "lcmu_your_token_here"
}
```

```bash
chmod 600 .patchcreator.local
```

Add `.patchcreator.local` to the project's `.gitignore` — it contains a bearer token.

If neither source is present, the upload step is silently skipped.

### Upload behavior

- **201** — success
- **409 (same SHA)** — already uploaded; exits 0 (idempotent retry)
- **409 (different SHA)** — version conflict; exits non-zero
- **429** — honors `Retry-After`, retries once
- **5xx / network error** — exponential backoff, up to 4 attempts

---

## Cumulative Base Resolution

When no `-b` is given, PatchCreator resolves the diff base in this order:

1. Reads `built_from_commit` from the highest-version `patch-*.tgz` in the output directory, if it is an ancestor of HEAD.
2. Falls back to the git tag matching that archive's version (`vX.Y.Z` or `X.Y.Z`).
3. Falls back to the latest reachable git tag (first-run behavior).
4. Aborts if none of the above can be resolved — pass `-b` explicitly.

Archives whose version is ≥ the target version are skipped to handle rebuilds cleanly.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error (invalid arguments, missing files) |
| 2 | No changed or deleted files to package |
| 3 | Git error (not a repository, invalid reference) |
| 4 | User cancelled |
| 5 | Build succeeded but upload to LicenseManager failed |

---

## Compatibility

| PatchModule version | Feature |
|---------------------|---------|
| v1.00.00+ | Core archive format |
| v1.3.0+ | `removed_files` field (older versions silently ignore it) |
| v1.8.0+ | `migrations[]` execution |

Build-time manifest validation mirrors PatchModule v1.8.0 rules. Use `--no-validate` to skip.

### Dual-language release notes

When `CHANGELOG.hu.md` is present alongside `CHANGELOG.md` (same Keep a Changelog format, identical `## [X.Y.Z] - date` headers), `release_notes.md` inside the archive contains `# English` and `# Magyar` sections. Projects without `CHANGELOG.hu.md` produce single-language output, byte-identical to pre-v1.09.00 output.

> Displaying only the user's language requires a future PatchModule update. Until then, both sections are shown stacked.
