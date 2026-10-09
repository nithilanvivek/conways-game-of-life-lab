# Conway's Game of Life Lab

Open-source app editions by Nithilan Vivek. [Project website](https://nithi.land/projects/conways-game-of-life/). MIT applies to original code/assets; see [LICENSE](LICENSE) and [third-party notices](THIRD-PARTY-NOTICES.md).

## Source editions

- `apps/conway-native/`: native macOS, Windows, Linux and Android/ChromeOS sources, shared assets, tests and build scripts.
- `assets/downloads/conways-game-of-life/Conway.py`: legacy v2 desktop source.
- `apps/android/conways-game-of-life-lab/`: offline mobile and ChromeOS WebView editions, with shared Android infrastructure.
- `apps/conways-game-of-life-lab-ios/`: offline iOS WebView edition and build instructions.
- `apps/linux/`: legacy AppImage/DEB build script for this app only.

## Releases

Download packages from [GitHub Releases](https://github.com/nithilanvivek/conways-game-of-life-lab/releases). Compiled packages are release attachments, not committed to source history. Checksums accompany downloads. Windows/macOS packages are republished unchanged. Native Linux and ChromeOS packages were built and verified on 2026-10-09; their evidence and requirements are documented below.

The public desktop release is v3.0. Its existing Windows payload has internal version 3.2-testing; the Mac app has internal version 3.1/build 8. Package names and app identities are preserved. The public native ChromeOS v3.0 APK is non-debuggable and release-signed with the same permanent nithi.land certificate as v2.0. It keeps the ChromeOS app ID and updates versionCode to 10. Native Linux v3.0 AppImage/DEB packages are available for x86_64 and ARM64, targeting Ubuntu 24.04 or compatible recent Linux. They are not Flatpaks. Legacy mobile Android v2.0 and Store builds remain separate editions.

## Native Linux build

Install a C11 compiler, pkg-config, GTK3 and JSON-GLib development packages, then run `make -C apps/conway-native/linux`. The binary is `apps/conway-native/linux/nithi-life`. Distribution installation uses the existing `install-dist` target; read the Linux packaging instructions before installing. CI checks x86_64 and aarch64 builds, engine/history tests, isolated GTK UI and metadata. A Flatpak manifest and actual sandbox validation remain pending.

## Building mobile editions

See each platform README. Android builds require a suitable JDK, Android SDK and the bundled Gradle wrapper. Release signing uses externally supplied environment variables and your own key. No release keys or passwords are included. iOS builds require macOS/Xcode and your own signing configuration. Source layout is preserved so relative build paths remain valid.

## Contributing

Open issues and pull requests in this repository. Current app source lives here; nithi.land retains deployed copies and historical download URLs. Do not commit personal charts, autosaves, databases, credentials or signing material.

## Native v3.0 package update — 2026-10-09

The original `v3.0` tag and `conways-game-of-life-lab-3.0-source.tar.gz` attachment remain immutable. Updated package source is pinned separately by `v3.0-packages.1` and the `conways-game-of-life-lab-3.0-packages-source.tar.gz` attachment on the v3.0 release. It includes the package scripts, public v3.0 labels and release signing configuration; no Meson conversion was made.

Linux package CI run 37904649763 passed DEB upgrade/install and AppImage extracted/runtime launch on both architectures. AppImages bundle GTK resources and dependency notices; DEB dependencies come from dpkg-shlibdeps. Read `apps/conway-native/linux/packaging/README.md`. ChromeOS release build/lint, signature verification, in-place update from the old signed APK and all 10 headless Android desktop user-flow instrumentation tests passed. The release certificate SHA-256 is `6990fa6f245dc4eea9c282037777cce9cb37500e67fd927c65bf653c078a18e0`. Actual Chromebook/Flatpak sandbox testing remains separate.
