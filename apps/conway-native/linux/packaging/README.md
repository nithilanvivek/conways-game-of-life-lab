# Linux distribution preparation

This directory contains upstream desktop integration resources, not a Flathub submission manifest. The source and packaging were prepared with AI assistance. Current Flathub policy requires disclosure of that assistance and prohibits AI-generated or AI-assisted manifests and agent-generated submission interactions. A human must independently author the final Flathub manifest and conduct the submission. Do not treat these materials as an accepted or submission-ready Flatpak.

Policy: https://docs.flathub.org/docs/for-app-authors/requirements#generative-ai-policy

## Prepared upstream resources

- `land.nithi.life.desktop`: launcher and icon identity.
- `land.nithi.life.metainfo.xml`: AppStream metadata with the owner-approved MIT project license. The `.in` file remains a template for future metadata generation.
- `../../LICENSE`: MIT license approved by the owner on 2026-10-08. Third-party components retain their own licenses. This applies to the native app directory, not the entire website repository.
- `make install-dist PREFIX=/app`: installs the binary, icon, desktop entry and completed metadata. `DESTDIR` supports staged installation. The existing personal installer is unchanged.
- Import/Export now use `GtkFileChooserNative`, permitting the desktop file chooser portal inside a Flatpak sandbox.
- The app resolves its icon from system XDG data directories, including `/app/share`.

## Native validation evidence

[GitHub Actions run 37789103093](https://github.com/vivekroark-cpu/nithi.land/actions/runs/37789103093) built the app on Ubuntu 24.04 x86_64 and aarch64. Both architectures passed sanitizer engine/graph checks, saved-data compatibility, the isolated offscreen GTK smoke test, staged distribution installation and license comparison, desktop-entry validation and AppStream validation (exit code 0). Logs and genuine GTK screenshots are retained in CI artifacts. AppStream references the public Linux screenshot at `https://nithi.land/assets/conways-game-of-life/native-linux.png`.

These checks do not constitute a Flatpak runtime or sandbox pass. The approved installed Linux app and existing AppImage/DEB downloads are unchanged.

## Remaining release decisions and evidence

1. Done: add the owner-approved MIT license, complete project metadata, install the license, capture a genuine Linux screenshot and validate the desktop entry/AppStream metadata.
2. Publish a tagged stable source release including these resources. Flathub requires public, immutable source references and source builds for source-available software. The local preparation archive is not a publicly hosted release.
3. Independently author the Flathub manifest according to official documentation. Confirm the latest supported GNOME runtime/SDK branch at submission. The app requires GTK3, JSON-GLib, a C11 compiler and libm. No application network permission is needed.
4. Build in the chosen Flatpak runtime on Linux, and test the actual sandbox: launch, import/export through the portal, saved patterns/canvases, playback/history, all themes, and the tour. Test x86_64 and aarch64 builds.

The app stores autosave/session data beneath XDG_DATA_HOME. Its named canvas and pattern library defaults to `~/Conway Game of Life Canvases`. For the sandbox, decide whether to keep that folder privately persistent or grant narrow access to that specific existing user folder. Broad home, host, or device access is unnecessary. Preserve users’ existing saved files; do not silently migrate or delete them.

Validate after completing metadata:

```sh
desktop-file-validate land.nithi.life.desktop
appstreamcli validate --pedantic land.nithi.life.metainfo.xml
```

Requirements: https://docs.flathub.org/docs/for-app-authors/requirements

Metadata: https://docs.flathub.org/docs/for-app-authors/metainfo-guidelines

Submission: https://docs.flathub.org/docs/for-app-authors/submission
