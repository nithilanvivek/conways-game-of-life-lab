# Conway’s Game of Life Lab v3.1 — Mini Nithi

Use the latest synchronized source archive and verify its hash from the handoff message. The approved source-v10 native app was committed in 829aae3. Distribution preparation added afterward includes portal-compatible file dialogs, XDG system icon lookup, and Linux packaging resources; these changes passed fresh native builds; actual Flatpak sandbox testing remains required. The approved installed binary and archive are preserved. Earlier v3.0 and source-v1 snapshots are superseded.

The owner selected MIT on 2026-10-08. The native app's `LICENSE` and completed `linux/packaging/land.nithi.life.metainfo.xml` are included in the source preparation archive. `make -C linux install-dist PREFIX=/app DESTDIR=<isolated staging directory>` installs the license with desktop/icon/metadata resources. GitHub Actions run 37789103093 passed native builds, sanitizer engine/graph tests, saved-data compatibility, staged distribution installation, isolated offscreen GTK smoke tests, desktop-entry validation and AppStream validation on Ubuntu 24.04 x86_64 and aarch64. Logs and real screenshots are retained in the CI artifacts. This is native Linux verification, not a Flatpak sandbox pass. The existing desktop route was unavailable; CI provided separate isolated Linux hosts. Flathub manifests and submission interactions must be independently human-authored; no agent-generated submission manifest is included.

Build and install in the existing dot Linux workspace. Native C/GTK3/Cairo/JSON-GLib; Python is only used for the original-v2 compatibility test, not by the app. Reuse existing extracted official Debian dependencies and pkg-config sysroot. Do not install Linux dependencies on Mac or create a VM/tunnel.

The current source includes a native Cairo live-cell line graph (latest 2,048 generations, v2 population_history JSON, Undo/Redo/Back/reset), infinite coordinates, Specify Chart Size beside Canvas with finite sizes and Infinite, Default chart identity preserved through patterns/Undo/Reset, editable rules, themes, named shared-folder saves, previews, custom-pattern thumbnail cards, independent keyboard cursor, tours/highlights, clipboard and all keyboard edits. Pattern placement adds only live cells; clipboard paste replaces live and dead cells. O.O over an existing middle cell must leave three live cells; clipboard paste must clear the middle cell.

Tests:

```sh
cc -std=c11 -O1 -g -Wall -Wextra -Wno-unused-function -fsanitize=address,undefined tests/engine-c.c -o /tmp/conway-engine-test
ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1 /tmp/conway-engine-test
cc -std=c11 -O1 -g -Wall -Wextra -Wno-unused-function -fsanitize=address,undefined $(pkg-config --cflags json-glib-1.0) tests/population-c.c -o /tmp/conway-population-test $(pkg-config --libs json-glib-1.0) -lm
ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1 /tmp/conway-population-test
python3 tests/v2-compatibility.py
make -C linux
```

The compatibility harness falls back to tests/fixtures/v2-original-source.py and checked-in Swift/C# JSON fixtures when the original repository assets or generated test outputs are unavailable.

If GUI testing is authorized and a display is available, use the app’s isolated smoke test:

```sh
mkdir -p /tmp/conway-qa
LIFE_DATA_DIR=/tmp/conway-qa/library LIFE_SCREENSHOT=/tmp/conway-qa/linux-native.png XDG_DATA_HOME=/tmp/conway-qa/data xvfb-run -a -s '-screen 0 1400x1000x24' linux/nithi-life --smoke-test
```

Do not interact with an existing cloud desktop while the user’s takeover remains active. Do not claim a GUI pass from compilation/engine tests alone.

Install with linux/install-local.sh to the existing current-user paths: ~/.local/bin/nithi-life, ~/.local/share/applications/land.nithi.life.desktop and ~/.local/share/icons/hicolor/256x256/apps/land.nithi.life.png. Reuse ~/Conway Game of Life Canvases if it exists; create only if missing. LIFE_PREFIX permits an isolated installation check. Retain user-local runtime libraries if required by the binary.

Return distro/architecture/dependency/compiler versions, build warnings, test exit codes/logs, installed path and executable hash. Report GUI checks separately. Return a v3.1 Linux archive containing the matching compiled app, latest source, installer, icon and logs through the existing relay. Notify the Mac source session about any source fixes before packaging, so the delivered sources remain synchronized.

For graph testing, keep the app offscreen and render the actual draw_population callback with Cairo image surfaces and theme scenarios. The user subsequently authorized updating the actual Mini Nithi installation. A brief supported installation terminal step may be used, then return control; do not reopen the app or repeat UI tests. Preserve all running windows and saved data, and respect active desktop takeovers. An isolated build/install is separate from updating the actual consumer filesystem; report the latter only with a verified installed binary hash.
