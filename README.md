# PatchCreator

Patch Package Builder for PatchModule. Creates `.tgz` patch archives from a git diff, with SHA-256 verification and optional auto-upload to LicenseManager.

## Features

- **Git-based file detection** — diffs between a base ref and HEAD; cumulative patches build on the last archive's commit, not just the latest tag
- **SQL migration support** — `database/migrations/*.sql` files are auto-detected and shipped in a `migrations/` directory; no flag needed
- **Version auto-detection** — reads `define('APP_VERSION', ...)` from project source files
- **Release notes extraction** — parses Keep a Changelog format; supports dual-language output when `CHANGELOG.hu.md` is present
- **Manifest validation** — validates the generated archive against PatchModule's install-time rules at build time
- **Auto-upload** — optionally POSTs the finished archive to LicenseManager via a bearer token
- **Dry run** — preview what would be packaged without creating the archive
- **CI-friendly** — `-y` flag skips all prompts; configurable via environment variables

## Requirements

- Bash 4.0+
- git, tar (GNU), sha256sum, grep (with `-P`)
- `jq`
- `curl` — optional, only needed for `--upload`

## Installation

```bash
git clone https://github.com/PatrikMol/PatchCreator.git
sudo cp PatchCreator/PatchCreator.sh /usr/bin/PatchCreator.sh
sudo chmod +x /usr/bin/PatchCreator.sh
```

## Quick Start

```bash
# Auto-detect version, diff against latest tag, extract release notes
PatchCreator.sh

# Preview without creating the archive
PatchCreator.sh --dry-run

# Explicit version and base ref, non-interactive
PatchCreator.sh -v 2.33.0 -b v2.32.0 -y
```

See [doc/USAGE.md](doc/USAGE.md) for the full CLI reference, examples, output format, and upload configuration.

## License

Copyright (C) 2026 PatrikMol Solutions Kft. All rights reserved.
