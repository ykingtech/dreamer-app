# CodeMagic setup

The repository contains no signing certificates, provisioning profiles, keystores, API keys, or private credentials. Add those only in CodeMagic.

## 1. Connect the repository

Connect the GitHub repository in CodeMagic and select `codemagic.yaml` from the repository root.

## 2. Android signing

In CodeMagic, create an Android keystore named `dreamer_keystore`. Use package/application id `com.lankaknot.dreamer`.

## 3. iOS signing

Create an App Store Connect integration named `dreamer_app_store_connect`. The Apple Developer account must have the bundle id `com.lankaknot.dreamer` registered. Let CodeMagic create or fetch the App Store distribution certificate and provisioning profile.

## 4. Environment group

Create a CodeMagic environment group named `dreamer-secrets` with:

```text
DREAMER_WORKER_URL=https://dreamer-worker.whatthewithyking.workers.dev
```

Do not add the Gemini API key to the app or repository. It stays in the Cloudflare Worker Secret named `GEMINI_API_KEY`.

## 5. Local notifications

The app uses local notifications and does not require Firebase. Android and iOS users still need to grant notification permission. The app schedules the reminder using the device's local timezone.
