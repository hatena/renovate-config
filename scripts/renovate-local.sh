#!/usr/bin/env bash
# Dry-run Renovate presets locally against the fixtures under test/fixtures/,
# using the pinned Docker image in scripts/renovate-image.env.
#
# See README.md ("Development") for usage examples.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
FIXTURES_DIR="$REPO_ROOT/test/fixtures"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/renovate-image.env"

usage() {
  cat <<'EOF'
Usage:
  scripts/renovate-local.sh
      Suite mode: dry-run every (preset, fixture) pair defined in this
      script's SUITE array. This is what CI runs as a smoke test.

  scripts/renovate-local.sh -c CONFIG_FILE -f FIXTURE [-l LOG_LEVEL] [-e]
      Dry-run a preset file from the working copy directly
      (via RENOVATE_CONFIG_FILE), against test/fixtures/FIXTURE.
      Use this to check an *uncommitted* preset change before pushing.
      Note: if CONFIG_FILE has "extends" entries referencing other
      github>hatena/renovate-config presets (e.g. default.json), those are
      always resolved from the main branch on GitHub, not the working copy.

  scripts/renovate-local.sh -p PRESET -r BRANCH -f FIXTURE [-l LOG_LEVEL] [-e]
      Dry-run a preset resolved via github>hatena/renovate-config:PRESET#BRANCH
      against test/fixtures/FIXTURE. Use this after pushing a branch, to also
      exercise the github> resolution path.

Options:
  -c CONFIG_FILE  Preset file in the repo root, e.g. groupJest.json (default: default.json)
  -f FIXTURE      Fixture directory name under test/fixtures/, e.g. npm, docker, github-actions
  -p PRESET       Preset name as written after the colon in an extends entry,
                  e.g. groupJest or cpanfile.json5
  -r BRANCH       Branch already pushed to origin, used as the preset's #ref
  -l LOG_LEVEL    Renovate LOG_LEVEL (default: info)
  -e              Stop after the extract phase (--dry-run=extract, no network lookups)
  -h              Show this help
EOF
}

# (preset, fixture) pairs exercised in suite mode / CI.
SUITE=(
  "groupJest.json:npm"
  "groupLinters.json:npm"
  "automergeTypesMinor.json:npm"
  "limitDockerNodeUpdatesToLTS.json5:docker"
  "minimumReleaseAgeBehaviour.json:docker"
  "pinGitHubActionDigests.json:github-actions"
  "default.json:npm"
  "default.json:docker"
  "default.json:github-actions"
)

CONFIG_FILE=""
FIXTURE=""
PRESET=""
BRANCH=""
LOG_LEVEL="info"
DRY_RUN="lookup"
had_args=$#

while getopts "c:f:p:r:l:eh" opt; do
  case "$opt" in
    c) CONFIG_FILE="$OPTARG" ;;
    f) FIXTURE="$OPTARG" ;;
    p) PRESET="$OPTARG" ;;
    r) BRANCH="$OPTARG" ;;
    l) LOG_LEVEL="$OPTARG" ;;
    e) DRY_RUN="extract" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

resolve_github_token() {
  local token="${GITHUB_COM_TOKEN:-}"
  if [[ -z "$token" ]] && command -v gh >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null || true)"
  fi
  if [[ -z "$token" ]]; then
    echo "[renovate-local] warning: no GITHUB_COM_TOKEN available (set GITHUB_COM_TOKEN or run 'gh auth login'); lookups may hit GitHub rate limits" >&2
  fi
  printf '%s' "$token"
}

require_fixture_dir() {
  local fixture="$1"
  if [[ ! -d "$FIXTURES_DIR/$fixture" ]]; then
    echo "[renovate-local] fixture not found: $FIXTURES_DIR/$fixture" >&2
    return 1
  fi
  # --platform=local only extracts files known to git (tracked, or at least
  # `git add`-ed), so an untracked fixture silently extracts 0 package files.
  if [[ -n "$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "test/fixtures/$fixture")" ]]; then
    echo "[renovate-local] warning: test/fixtures/$fixture has untracked files; --platform=local won't see them until you 'git add' them" >&2
  fi
}

# Dry-run a preset file from the working copy directly.
run_one() {
  local config_file="$1" fixture="$2"
  # `set -e` is suspended for the whole function body when it's called as
  # part of a tested command (e.g. `if ! run_one ...`, as suite mode does
  # below), so a `return 1` from require_fixture_dir would otherwise be
  # ignored and execution would fall through to `docker run` regardless.
  if ! require_fixture_dir "$fixture"; then
    return 1
  fi

  local token
  token="$(resolve_github_token)"

  echo "[renovate-local] config=$config_file fixture=$fixture dry-run=$DRY_RUN"
  docker run --rm \
    -e RENOVATE_CONFIG_FILE="/usr/src/app/$config_file" \
    -e RENOVATE_REQUIRE_CONFIG=ignored \
    -e RENOVATE_ONBOARDING=false \
    -e GITHUB_COM_TOKEN="$token" \
    -e LOG_LEVEL="$LOG_LEVEL" \
    -v "$REPO_ROOT:/usr/src/app" \
    -v renovate-config-local-cache:/tmp/renovate \
    -w "/usr/src/app/test/fixtures/$fixture" \
    "$RENOVATE_IMAGE" \
    renovate --platform=local --dry-run="$DRY_RUN"
}

# Dry-run a preset resolved via github>hatena/renovate-config:PRESET#BRANCH.
run_branch() {
  local preset="$1" branch="$2" fixture="$3"
  # See the comment in run_one(): don't rely on `set -e` to act on this.
  if ! require_fixture_dir "$fixture"; then
    return 1
  fi

  # The temp config is written *inside* the repo checkout (rather than under
  # $TMPDIR) so it lands inside the single bind mount below. Docker Desktop /
  # Rancher Desktop's VM only shares specific host paths (typically $HOME);
  # bind-mounting a single file from outside that (e.g. a sandboxed $TMPDIR)
  # can silently produce an empty directory in the container instead of the
  # file's content.
  local tmp_dir="$REPO_ROOT/tmp"
  mkdir -p "$tmp_dir"
  local tmp_config="$tmp_dir/renovate-local-branch-config.json"
  printf '{"extends": ["github>hatena/renovate-config:%s#%s"]}\n' "$preset" "$branch" > "$tmp_config"

  local token
  token="$(resolve_github_token)"

  echo "[renovate-local] preset=$preset#$branch fixture=$fixture dry-run=$DRY_RUN"
  # Capture docker's exit status manually (rather than a RETURN trap) so the
  # temp config is cleaned up even when this function is called outside a
  # tested context (`run_branch ...; exit $?`), where a non-zero exit from
  # `docker run` would otherwise trigger `set -e` and skip any cleanup that
  # follows it.
  local status=0
  docker run --rm \
    -e RENOVATE_CONFIG_FILE=/usr/src/app/tmp/renovate-local-branch-config.json \
    -e RENOVATE_REQUIRE_CONFIG=ignored \
    -e RENOVATE_ONBOARDING=false \
    -e GITHUB_COM_TOKEN="$token" \
    -e LOG_LEVEL="$LOG_LEVEL" \
    -v "$REPO_ROOT:/usr/src/app" \
    -v renovate-config-local-cache:/tmp/renovate \
    -w "/usr/src/app/test/fixtures/$fixture" \
    "$RENOVATE_IMAGE" \
    renovate --platform=local --dry-run="$DRY_RUN" || status=$?
  rm -f "$tmp_config"
  return "$status"
}

if [[ -n "$PRESET" || -n "$BRANCH" ]]; then
  if [[ -z "$PRESET" || -z "$BRANCH" ]]; then
    echo "[renovate-local] -p and -r must be given together" >&2
    usage
    exit 1
  fi
  if [[ -n "$CONFIG_FILE" ]]; then
    echo "[renovate-local] -c cannot be combined with -p/-r" >&2
    usage
    exit 1
  fi
  if [[ -z "$FIXTURE" ]]; then
    echo "[renovate-local] -f is required" >&2
    usage
    exit 1
  fi
  run_branch "$PRESET" "$BRANCH" "$FIXTURE"
  exit $?
fi

if [[ $had_args -gt 0 ]]; then
  if [[ -z "$FIXTURE" ]]; then
    echo "[renovate-local] -f is required" >&2
    usage
    exit 1
  fi
  CONFIG_FILE="${CONFIG_FILE:-default.json}"
  run_one "$CONFIG_FILE" "$FIXTURE"
  exit $?
fi

# Suite mode (no arguments): run every pair, report failures at the end
# instead of stopping at the first one.
failures=0
for pair in "${SUITE[@]}"; do
  IFS=':' read -r config_file fixture <<< "$pair"
  if ! run_one "$config_file" "$fixture"; then
    echo "[renovate-local] FAILED: $config_file against $fixture" >&2
    failures=$((failures + 1))
  fi
done

if [[ $failures -gt 0 ]]; then
  echo "[renovate-local] $failures suite case(s) failed" >&2
  exit 1
fi
echo "[renovate-local] all suite cases passed"
