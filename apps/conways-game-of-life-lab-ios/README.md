# Conway's Game Of Life Lab 2.0 for iPad

An offline iPad edition of the full Conway's Game Of Life Lab. The Home Screen name intentionally has no version suffix; the app metadata and IPA are version 2.0.

Named canvases, custom patterns, settings, and tour progress persist in the app's private on-device storage. Tap **Choose Data Folder** to select any writable folder in Files or iCloud Drive. The app then imports the `.life.json` canvases in that folder, migrates private named canvases into it, and writes future saves there automatically. Those files survive app deletion and can be reopened by a newly sideloaded copy after selecting the same folder again.

The private store remains an offline fallback. Manual Import and Export continue to work with desktop-compatible `.life.json` documents.

## Implementation and Installation

This is a native Swift `WKWebView` shell around bundled HTML, CSS, and JavaScript. It does not contain Python and needs no server or internet connection.

The original Mac `.icns` was used only as source artwork. The iPad app uses an opaque PNG in `Assets.xcassets`; Xcode compiles the required iOS icon resources into the app package.

The finished IPA can be installed with Xcode's Devices and Simulators window, Apple Configurator, or Sideloadly. A sideloaded development build still requires Developer Mode on the iPad. When using a free Apple ID, re-sign or refresh the app before its seven-day profile expires.

## Build

Open `ConwaysGameOfLifeLab.xcodeproj`, select the `ConwaysGameOfLifeLab` scheme, choose an iPad simulator or connected iPad, and run. Physical-device builds use automatic signing with the selected Apple development team.

The device-specific development IPA is generated under the repository's ignored `dist/ios/` directory.

After Xcode has signed and run the app once, it can be rebuilt and packaged from the command line:

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID \
DEVICE_UDID=YOUR_IPAD_UDID \
./scripts/build-device-ipa.sh
```

The script verifies the app signature and IPA zip structure before succeeding. A free Personal Team profile expires after seven days, so rebuild and reinstall the IPA when needed.
