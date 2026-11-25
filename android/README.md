# NetScope for Android

Android version of NetScope (v1.3). Pure Java on the Android SDK, no libraries or frameworks. Minimum Android 8.0 (API 26), target API 33.

A ready-to-install APK is on the Releases page. This folder holds the source so you can build it yourself.

## What is in this folder

- `AndroidManifest.xml`
- `src/com/jo0sef/netscope/`: the app code (`MainActivity.java`, `Net.java`, `Speed.java`, `UI.java`, `I18n.java`)
- `res/drawable/`: vector tab icons

Not included:

- `res/mipmap-xxhdpi/ic_launcher.png`: the app icon (a binary file). Add any 144x144 PNG at that path, or remove the `android:icon` attribute from the manifest.
- The MAC vendor lookup table (`assets/oui.txt`, read at runtime). Without it the app still builds and runs, but device vendor names are not shown. MAC and vendor data is only readable on Android 8 and 9 anyway. Android 10 and later block it.

## Build without Gradle

You need a JDK (11 or later) and the Android SDK command-line tools with platform `android-33` and build-tools installed. Set `ANDROID_HOME` to the SDK path and `BT` to the build-tools folder.

```
BT=$ANDROID_HOME/build-tools/33.0.2
JAR=$ANDROID_HOME/platforms/android-33/android.jar
mkdir -p build/classes build/dex

$BT/aapt2 compile --dir res -o build/res.zip
$BT/aapt2 link -o build/app.unsigned.apk -I $JAR --manifest AndroidManifest.xml \
  --min-sdk-version 26 --target-sdk-version 33 --java build/gen build/res.zip

javac -source 8 -target 8 -cp $JAR -d build/classes $(find src build/gen -name '*.java')
$BT/d8 --min-api 26 --lib $JAR --output build/dex $(find build/classes -name '*.class')

cd build/dex && zip -q ../app.unsigned.apk classes.dex && cd ../..
$BT/zipalign -f 4 build/app.unsigned.apk build/app.aligned.apk
```

Sign it with your own key. Never commit a keystore to this repo.

```
keytool -genkeypair -keystore my.keystore -alias netscope -keyalg RSA -keysize 2048 -validity 10000
$BT/apksigner sign --ks my.keystore --out NetScope.apk build/app.aligned.apk
```

These steps were written from the project's file layout and have not been run exactly as shown, so adjust paths or tool versions if something fails.

## Notes

- The Wi-Fi name needs the location permission (asked once, optional).
- The phone must be on Wi-Fi to scan.
- Android 10 and later hides MAC addresses from apps.
