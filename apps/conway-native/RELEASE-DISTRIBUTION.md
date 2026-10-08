# Desktop release distribution — 2026-10-08

The requested public release announcement uses **Conway's Game of Life Lab v3.0**. Its Windows installer includes the approved 3.2-testing executable (file version 3.2.0.4); its Mac DMG contains the approved 3.1/build 8 app, whose window title already displays v3.0. These internal versions, filenames and compiled app contents are preserved.

## Windows setup

`windows/installer.nsi` builds `ConwayInstaller-3.0.exe` with NSIS 3.13. Setup installs for the current account under LocalAppData/Programs, needs no administrator elevation, creates Start-menu launch/uninstall shortcuts and registers itself in Windows installed apps. It requires 64-bit Windows 10 or later and embeds the existing self-contained executable; no separate .NET installation is required.

The uninstaller deletes only the files and shortcuts created by setup and its own registry entry. It does not recursively remove directories or touch named canvases, patterns, preferences or autosaves. Native Windows installation/upgrade/uninstallation has not yet been exercised; compilation and archive checks do not replace that test. The installer is unsigned.

Build from the repository root:

```sh
apps/conway-native/scripts/package-windows-installer.sh \
  dist/conway-native/final/Windows/Conways-Game-of-Life-Lab-3.2-testing.exe \
  dist/conway-native/final/Windows/ConwayInstaller-3.0.exe
```

The installer passes 7-Zip integrity checking; its extracted executable SHA256 exactly matches the approved payload. Third-party .NET license and notices are embedded alongside the app. `assets/downloads/conways-game-of-life/SHA256SUMS-3.0.txt` identifies the installer and unchanged DMG copied into the website download directory.

## Website

Both download groups on the Conway article use the new Windows setup and macOS DMG installation routes. The installation guide identifies platform requirements and v3.0 for those two routes; older downloads retain their earlier version labels. The Mac image requires Apple Silicon/macOS 14+ and remains ad-hoc signed and unnotarized.

The release ticker appears on site pages, links to the Conway article, and can be dismissed. Entering the homepage or Conway article clears the dismissal and renews it, including history-restored visits. Other pages honor dismissal. Reduced-motion preferences show static wrapping text; unavailable local storage does not prevent operation.

## APK signing history and Linux licensing

The older website ChromeOS APK is a non-debuggable release build signed by the permanent nithi.land certificate (CN=Nithilan, O=nithi.land, C=IN; SHA256 6990fa6f245dc4eea9c282037777cce9cb37500e67fd927c65bf653c078a18e0). The new native testing APK uses the Android Debug certificate. A permanent release keystore and Keychain-backed signing workflow already exist outside Git and can be reused for a native release build. No private key or password belongs in website assets. APK signing is separate from choosing an application copyright/redistribution license.

Linux preparation remains under `linux/packaging`. The owner selected MIT on 2026-10-08; `LICENSE` records the terms, completed AppStream metadata declares MIT, and `install-dist` installs the license. Native Ubuntu 24.04 x86_64 and aarch64 builds, sanitizer engine/graph checks, saved-data compatibility, isolated GTK smoke tests, staged distribution installation, desktop validation and AppStream validation passed in GitHub Actions run 37789103093. A genuine Linux screenshot is provided in AppStream metadata. A tagged stable upstream source release and real Flatpak runtime/sandbox tests remain pending. A human must independently author the Flathub manifest and conduct submission, and disclose the known AI-assisted application/packaging material under current Flathub policy. No AI-authored manifest or submission PR is provided.
