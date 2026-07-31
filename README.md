# renovate-config

A [shareable config preset for Renovate](https://docs.renovatebot.com/config-presets/) used in [Hatena](https://hatena.co.jp/).

```json
{
  "extends": [
    "github>hatena/renovate-config"
  ]
}
```

## Available presets

### autoMergePin

```json
{
  "pin": {
    "automerge": true
  }
}
```

### autoMergeTypesMinor

```json
{
  "packageRules": [
    {
      "matchPackagePatterns": ["^@types/"],
      "automerge": true,
      "major": {
        "automerge": false
      }
    }
  ]
}
```

### ecspressoVersion.json5 (opt-in)

Updates the [ecspresso](https://github.com/kayac/ecspresso) version defined in the `.ecspresso-version` file using `customManagers`.

```json
{
  "extends": ["github>hatena/renovate-config:ecspressoVersion.json5"]
}
```

### groupAndroidPackages

Grouping various libraries used for Android app development, mainly based on Maven groupId.

### groupCocoaPodsPackages

Grouping some CocoaPods libraries used for iOS app development.

### groupJest

Grouping jest monorepo packages and ts-jest.

```json
{
  "packageRules": [
    {
      "groupName": "jest",
      "matchSourceUrlPrefixes": [
        "https://github.com/facebook/jest",
        "https://github.com/kulshekhar/ts-jest"
      ]
    }
  ]
}
```

### groupLinters

Grouping lint-related packages for JavaScript and TypeScript. Adding prettier and typescript-eslint packages to the [`packages:linters` preset](https://docs.renovatebot.com/presets-packages/#packageslinters).

```json
{
  "packageRules": [
    {
      "groupName": "linters",
      "extends": ["packages:linters"],
      "matchPackageNames": ["prettier"],
      "matchPackagePatterns": ["^@typescript-eslint/"]
    }
  ]
}
```

### schedule

```json
{
  "extends": [
    ":timezone(Asia/Tokyo)"
  ],
  "schedule": [
    "after 10:30 before 18:00 every weekday except after 13:00 before 14:00"
  ]
}
```

This config is heavily based on our business hours in Hatena. So if this is not a good fit for you, please exclude as follows:

```json
{
  "ignorePresets": ["github>hatena/renovate-config:schedule"]
}
```

or overwrite the [`schedule` option](https://docs.renovatebot.com/configuration-options/#schedule) as you like:

```json
{
  "schedule": ["after 10pm and before 5am on every weekday", "every weekend"]
}
```

or extend the [Schedule Presets](https://docs.renovatebot.com/presets-schedule/).

### xcodegenSwiftPackages.json5 (opt-in)

Updates Swift packages in XcodeGen's `project.yml` using `customManagers`.

- https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#swift-package

```json
{
  "extends": ["github>hatena/renovate-config:xcodegenSwiftPackages.json5"]
}
```

## Development

Changing a preset normally means "merge, then wait for Renovate to run somewhere and see what happens." The scripts below let you dry-run a preset locally instead, based on [this article](https://blog.1q77.com/2025/01/renovate-local-debug/).

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (e.g. via Rancher Desktop)
- [GitHub CLI](https://cli.github.com/) (`gh`), used to supply a `GITHUB_COM_TOKEN` for lookups if one isn't already set in your environment

### Validate configs

Same schema check as CI (`renovate-config-validator`), runnable locally:

```sh
./scripts/validate-config.sh
```

### Dry-run presets against fixtures

`test/fixtures/` contains small sample manifests (npm, Dockerfile, GitHub Actions) used to check that a preset actually detects updates, without needing a real repository. `scripts/renovate-local.sh` wraps `renovate --platform=local` against them using the Docker image pinned in `scripts/renovate-image.env`.

Run the whole suite (also what CI runs as a smoke test):

```sh
./scripts/renovate-local.sh
```

Dry-run a preset from your working copy, before pushing:

```sh
./scripts/renovate-local.sh -c groupJest.json -f npm
```

Dry-run a preset from a pushed branch, resolved via `github>hatena/renovate-config:PRESET#BRANCH` (also exercises the `github>` resolution path):

```sh
git push origin my-branch
./scripts/renovate-local.sh -p groupJest -r my-branch -f npm
```

Add `-l debug` for verbose logs, or `-e` to stop after the extract phase (no network calls). Run `./scripts/renovate-local.sh -h` for full usage.

### Caveats

- `default.json`'s `github>hatena/renovate-config:xxx` entries always resolve from `main` on GitHub, never from your working copy or a pushed branch. Dry-run the preset you actually changed with `-c`/`-p`, and only rely on `default.json` for an end-to-end smoke test after merging.
- `--platform=local` is an [experimental Renovate feature](https://docs.renovatebot.com/modules/platform/local/). It only goes through the extract and lookup phases, so PR-behavior options (`schedule`, `automerge`, branch creation, etc.) can't be verified this way.
- `--platform=local` only extracts files known to git (tracked, or at least `git add`-ed). If you add a new fixture file and forget to `git add` it, Renovate silently reports 0 package files instead of an error; `renovate-local.sh` warns about this when it detects untracked files under the fixture you're targeting. This doesn't affect editing an *existing* (already-tracked) preset or fixture file — uncommitted edits to a tracked file are picked up fine.
- Fixtures live under `test/`, which `config:base` already excludes from real Renovate runs (via `**/test/**` in `:ignoreModulesAndTests`) so they won't get their own update PRs in this repository. If `default.json` ever stops extending `config:base`, re-check that this still holds.
- Lookups need outbound network access (e.g. `api.github.com`, package registries).
- The suite (and CI's `dry-run` job) only checks that Renovate exits successfully against each fixture. A passing run means the preset didn't crash and recognized the fixture's files — it does *not* by itself confirm that a `groupName`, `automerge`, or `pinDigests` rule actually applied as intended. Read the logged output (`-l debug`) when you want to confirm the specific behavior a preset change is meant to produce.
