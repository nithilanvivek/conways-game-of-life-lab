# Conway's Game of Life Lab

Open-source app editions by Nithilan Vivek. [Project website](https://nithi.land/projects/conways-game-of-life/). MIT applies to original code/assets; see [LICENSE](LICENSE) and [third-party notices](THIRD-PARTY-NOTICES.md).

## Source editions

- `apps/conway-native/`: native macOS, Windows, Linux and Android/ChromeOS sources, shared assets, tests and build scripts.
- `assets/downloads/conways-game-of-life/Conway.py`: legacy v2 desktop source.
- `apps/android/conways-game-of-life-lab/`: offline mobile and ChromeOS WebView editions, with shared Android infrastructure.
- `apps/conways-game-of-life-lab-ios/`: offline iOS WebView edition and build instructions.
- `apps/linux/`: legacy AppImage/DEB build script for this app only.

## Releases

Download packages from [GitHub Releases](https://github.com/nithilanvivek/conways-game-of-life-lab/releases). Compiled packages are release attachments, not committed to source history. Checksums accompany downloads. Existing files are republished unchanged; publishing them does not add new platform testing or signing.

The public desktop release is v3.0. Its existing Windows payload has internal version 3.2-testing; the Mac app has internal version 3.1/build 8. Package names and app identities are preserved. The current native ChromeOS APK is debug-signed and remains a testing edition. Legacy Android/ChromeOS v2.0 packages are separate release-signed editions. Native Linux binaries require compatible GTK3/JSON-GLib system libraries; they are not Flatpaks.

## Native Linux build

Install a C11 compiler, pkg-config, GTK3 and JSON-GLib development packages, then run `make -C apps/conway-native/linux`. The binary is `apps/conway-native/linux/nithi-life`. Distribution installation uses the existing `install-dist` target; read the Linux packaging instructions before installing. CI checks x86_64 and aarch64 builds, engine/history tests, isolated GTK UI and metadata. A Flatpak manifest and actual sandbox validation remain pending.

## Building mobile editions

See each platform README. Android builds require a suitable JDK, Android SDK and the bundled Gradle wrapper. Release signing uses externally supplied environment variables and your own key. No release keys or passwords are included. iOS builds require macOS/Xcode and your own signing configuration. Source layout is preserved so relative build paths remain valid.

## Contributing

Open issues and pull requests in this repository. Current app source lives here; nithi.land retains deployed copies and historical download URLs. Do not commit personal charts, autosaves, databases, credentials or signing material.
