# Meta Share

Flutter app that lets you pick a photo and hand it straight to Instagram or Facebook.

- **Instagram Story** opens the story composer with the photo as the background.
- **Instagram Feed** sends the photo into Instagram’s post composer.
- **Facebook Story** opens the Facebook story composer with the photo.
- **Facebook Feed** opens the Facebook composer on Android. On iPhone, Meta has no direct image-to-feed hook, so the system share sheet opens and you choose Facebook.

Sharing uses Meta’s documented handoff, not the Instagram Graph API:

- [Sharing to Stories](https://developers.facebook.com/documentation/instagram-platform/sharing-to-stories/)
- [Sharing to Feed](https://developers.facebook.com/documentation/instagram-platform/sharing-to-feed/)

Stories require a Facebook App ID. That ID is set in `lib/meta_config.dart`.

## Requirements

- Flutter SDK
- A phone or emulator with Instagram and/or Facebook installed
- A Meta app at [developers.facebook.com](https://developers.facebook.com/apps/)

Stories sharing does not work in a browser. Run the Android or iOS build.

## Meta dashboard

Create an app and leave the use cases empty. If a use case is required, choose **Other**. Do not add **Manage messaging and content on Instagram**. That use case is for the publishing API, which this app does not use.

Under **App settings → Basic**, add:

| Platform | Value |
| --- | --- |
| Android package name | `com.share1.app` |
| Android class name | `com.share1.app.MainActivity` |
| Android key hash | See below |
| iOS bundle ID | `com.share1.app` |

Paste the numeric **App ID** into `facebookAppId` in `lib/meta_config.dart`.

This project signs debug and release builds with the debug keystore. Generate its key hash and paste it into **Key hashes**:

```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

If a Play Store build is signed with a different key, add that key’s hash as well and keep the debug hash for local builds.

## Run

```bash
flutter pub get
flutter run
```

Release APK:

```bash
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## How sharing works

| Destination | Android | iOS |
| --- | --- | --- |
| Instagram Story | `com.instagram.share.ADD_TO_STORY` | `instagram-stories://share` with the image on the pasteboard |
| Instagram Feed | `ACTION_SEND` to `com.instagram.android` | `.igo` file opened with `com.instagram.exclusivegram` |
| Facebook Story | `com.facebook.stories.ADD_TO_STORY` | `facebook-stories://share` with the image on the pasteboard |
| Facebook Feed | `ACTION_SEND` to the Facebook app | System share sheet |

The photo is passed as a content URI on Android and as image data or a local file on iOS. The user still publishes it inside Instagram or Facebook.

## Project layout

- `lib/main.dart` — photo picker and share buttons
- `lib/meta_config.dart` — Facebook App ID
- `lib/meta_share.dart` — platform channel
- `android/app/src/main/kotlin/com/share1/app/MetaShareHandler.kt` — Android intents
- `ios/Runner/AppDelegate.swift` — iOS pasteboard, URL scheme, and document handoff
