#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PATCHCREATOR="${SCRIPT_DIR}/../PatchCreator.sh"

# Regression test for issue #2: a git-detected rename (R-status) only ever
# reported its NEW path via `--name-only`, so the OLD path never made it
# into manifest.json's removed_files — orphaning the old file on every
# client install. Runs the real script end-to-end against a throwaway repo.

REPO_DIR="$(mktemp -d)"
trap 'rm -rf "$REPO_DIR"' EXIT

cd "$REPO_DIR"
git init -q
git config user.email test@test.com
git config user.name test
mkdir -p app/views/partials
echo "<?php echo 'nav';" > app/views/partials/admin_nav.php
git add -A
git commit -qm "initial"
git tag v1.0.0

git mv app/views/partials/admin_nav.php app/views/partials/admin_sidebar.php
git commit -qam "rename nav to sidebar"

bash "$PATCHCREATOR" -b v1.0.0 -v 1.0.1 -o "${REPO_DIR}/out" \
    --no-changelog --no-validate --no-upload -y > /dev/null 2>&1

MANIFEST_JSON="$(tar -xzOf "${REPO_DIR}/out/patch-1.0.1.tgz" ./manifest.json)"

fail=0

if echo "$MANIFEST_JSON" | jq -e '.removed_files | index("app/views/partials/admin_nav.php")' > /dev/null; then
    echo "PASS: renamed file's old path is in removed_files"
else
    echo "FAIL: renamed file's old path is missing from removed_files"
    fail=1
fi

if echo "$MANIFEST_JSON" | jq -e '.files | index("app/views/partials/admin_sidebar.php")' > /dev/null; then
    echo "PASS: renamed file's new path is in files"
else
    echo "FAIL: renamed file's new path is missing from files"
    fail=1
fi

exit $fail
