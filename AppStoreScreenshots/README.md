# App Store Screenshot Capture

Run:

```sh
scripts/capture_app_store_screenshots.sh
```

The workflow captures iPad and macOS screenshots through `LunaAppStoreScreenshotUITests`.
Raw PNG attachments are exported under `AppStoreScreenshots/raw`, and optional captioned
composites are generated under `AppStoreScreenshots/composites`.

Override destinations when needed:

```sh
IPAD_DESTINATION="platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
MAC_DESTINATION="platform=macOS" \
scripts/capture_app_store_screenshots.sh
```

Screenshot mode is isolated behind `-screenshotMode` / `-screenshotScreen` launch
arguments. It completes onboarding, fixes demo content, disables daily randomness, and
uses a static room background for AR placement screenshots without starting ARKit.
