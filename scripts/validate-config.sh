#!/usr/bin/env bash
# Validate every preset file in the repo root with renovate-config-validator,
# using the pinned Docker image in scripts/renovate-image.env.
#
# This is the same check CI runs (see .github/workflows/validate-config.yml).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/renovate-image.env"

cd "$REPO_ROOT"

for file in *.json*; do
  echo "[validate-config] Validating $file"
  docker run --rm \
    -v "$REPO_ROOT:/usr/src/app" \
    -w /usr/src/app \
    "$RENOVATE_IMAGE" \
    renovate-config-validator --no-global "$file"
done
