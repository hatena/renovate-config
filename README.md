# renovate-config

A [shareable config preset for Renovate](https://docs.renovatebot.com/config-presets/) used in [Hatena](https://hatenacorp.jp/).

```json
{
  "extends": [
    "github>hatena/renovate-config"
  ]
}
```

If you want to use this with private npm modules on Github Packages, some additional fields are required:

```json
{
  "encrypted": {
    "npmToken": "<Personal access token encoded w/ https://renovatebot.com/encrypt>"
  },
  "npmrc": "@hatena:registry=https://npm.pkg.github.com/\n//npm.pkg.github.com/:_authToken=${NPM_TOKEN}",
}
```
For the details, please refer to [official document](https://docs.renovatebot.com/private-modules/).
