#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PATCHCREATOR="${SCRIPT_DIR}/../PatchCreator.sh"

# Extract just the matches_exclude() function body so we test the real
# implementation without executing the rest of the script (which parses
# CLI args and expects a git repo).
FUNC_SRC="$(sed -n '/^matches_exclude()/,/^}/p' "$PATCHCREATOR")"
eval "$FUNC_SRC"

fail=0
assert_excluded() {
    local file="$1" pattern="$2"
    if matches_exclude "$file" "$pattern"; then
        echo "PASS: '$file' excluded by '$pattern'"
    else
        echo "FAIL: '$file' should be excluded by '$pattern' but was not"
        fail=1
    fi
}
assert_not_excluded() {
    local file="$1" pattern="$2"
    if matches_exclude "$file" "$pattern"; then
        echo "FAIL: '$file' should NOT be excluded by '$pattern' but was"
        fail=1
    else
        echo "PASS: '$file' not excluded by '$pattern'"
    fi
}

# Regression: PatchCreator issue — 'storage/' exclude (meant for the
# top-level runtime storage/ dir) was also matching any path containing
# "storage/" at any depth, silently dropping these files from every patch.
assert_excluded     "storage/logs/error.log"                       "storage/"
assert_excluded     "storage/cache/foo.php"                        "storage/"
assert_not_excluded "app/views/admin/storage/report.php"           "storage/"
assert_not_excluded "app/views/admin/settings/storage/warehouses.php" "storage/"
assert_not_excluded "app/views/mobile/storage/scan.php"            "storage/"

# Sanity: other default directory excludes still anchor to root only
assert_excluded     "vendor/some/lib.php"                          "vendor/"
assert_not_excluded "app/services/VendorImportService.php"         "vendor/"

exit $fail
