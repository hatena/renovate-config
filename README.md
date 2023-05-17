# renovate-config

A [shareable config preset for Renovate](https://docs.renovatebot.com/config-presets/) used in [Hatena](https://hatenacorp.jp/).

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

Updates the [ecspresso](https://github.com/kayac/ecspresso) version defined in the `.ecspresso-version` file using `regexManagers`.

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
