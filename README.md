# NetScope

NetScope is a network toolkit for iPhone and Android. It finds devices on your Wi-Fi network and gives you the usual diagnostic tools in one app.

Current version: **1.8**

## Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/6c3f8714-bb5c-4636-aa13-53bb5a1f79f1" width="220"> <img src="https://github.com/user-attachments/assets/2dbb2f3b-4265-4913-b4ab-11188b4f7580" width="220"> <img src="https://github.com/user-attachments/assets/534c207c-f997-455a-9163-5ce822aaeacc" width="220"> <img src="https://github.com/user-attachments/assets/607ece23-8050-4956-9f24-a7cafdaa6861" width="220">
</p>

## Features

- Network device scanner
- Ping and port scan
- Traceroute
- Speed test with history
- 9 themes
- English and Arabic UI
- Requires iOS 14 or later (iOS app). An Android version (Android 8.0 or later) is on the Releases page too.

## Install on Android

Download `NetScope-android-v1.8.apk` from the Releases page, open it, and allow "Install unknown apps" when asked. Needs Android 8.0 or later. Later updates: Settings > Check for app update.

## Install on iOS (unsigned IPA)

Download `NetScope-v1.8.ipa` from the Releases page. NetScope shows a notice in Settings when a newer version is out, and opens the release page. The IPA is unsigned, so you must sign it with your own Apple ID using one of the tools below.

### 3uTools (Windows)

1. Install 3uTools and connect your iPhone with a cable. Tap "Trust" on the phone.
2. Open **Toolbox > IPA Signature** (or **Apps > Import & Install IPA**, depending on your version).
3. Select the IPA, sign in with your Apple ID, and click sign/install.
4. On the iPhone, go to **Settings > General > VPN & Device Management**, trust your Apple ID profile, then open the app.

### AltStore

1. Install AltServer on your computer and install AltStore on your iPhone (see https://altstore.io).
2. Open AltStore on the phone, go to **My Apps**, tap **+**, and pick the IPA.
3. Trust your profile in **Settings > General > VPN & Device Management** if asked.
4. Keep AltServer running on the same Wi-Fi so AltStore can refresh the app.

### Sideloadly

1. Install Sideloadly (https://sideloadly.io) and connect your iPhone.
2. Drag the IPA into Sideloadly, enter your Apple ID, and click **Start**.
3. Trust your profile in **Settings > General > VPN & Device Management**.
4. On iOS 16 and later, enable **Developer Mode** (Settings > Privacy & Security) if the app will not open.

### Free signing: 7-day limit

With a free Apple ID, the signature expires after **7 days**, and the app stops opening. Re-sign and reinstall it (AltStore can refresh it automatically). A free account also allows only 3 sideloaded apps at a time. A paid Apple Developer account lasts one year.

## Build from source

NetScope is a single Objective-C file (`main.m`, UIKit) with an `Info.plist`. You can build it without a Mac using clang and lld with an iOS SDK:

```
clang -target arm64-apple-ios14.0 -isysroot iPhoneOS16.5.sdk -fobjc-arc -O2 -c main.m -o main.o
clang -target arm64-apple-ios14.0 -isysroot iPhoneOS16.5.sdk -fuse-ld=lld main.o \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -o NetScope
```

Put `NetScope` and `Info.plist` in `Payload/NetScope.app/`, add the app icon PNGs (`Assets/icon-1024.png` is the master), zip `Payload` as an `.ipa`, then sign it with your Apple ID using one of the tools above.

Note: iOS does not expose MAC addresses to apps.

## Disclaimer

NetScope is a personal and educational project. It comes with no warranty and no support promise. Developed by Youssef elbaheriy. Only scan networks and devices you own or have permission to test. You are responsible for how you use it.

## License

MIT. See [LICENSE](LICENSE).
