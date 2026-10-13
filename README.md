# Astral Studio

Downloads for all of Anish's Android apps: https://astral-studio.web.app

APKs live in this repo's GitHub Releases; the site reads `public/apps.json`.

Publish a new version from any project:

```
node release.mjs --app <id> --name "<App Name>" --version 1.2.0 --apk path/to/app.apk --notes "What changed"
```

The first release of an app can also pass `--tagline "..."` and `--icon path/to/icon.png`.
Each app keeps a permanent link to its newest APK: `https://astral-studio.web.app/get/<id>`.
