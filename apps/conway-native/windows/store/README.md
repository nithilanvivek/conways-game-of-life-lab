# Microsoft Store package 3.0.0.0

The Store identity comes from the owner's Partner Center product:

- Name: `NithilanVivek.ConwaysGameOfLifeLab`
- Publisher: `CN=9743AFE3-744A-4F36-BFC2-92F48F9B7C59`
- Publisher display name: `Nithilan Vivek`
- Package family: `NithilanVivek.ConwaysGameOfLifeLab_374284vg01p82`
- Package and executable versions: `3.0.0.0`; visible app version: `3.0`.

Run the manual **Package Conway Microsoft Store** GitHub workflow, or on Windows
with .NET 10, Python/Pillow and the Windows SDK:

```powershell
./apps/conway-native/scripts/package-windows-store.ps1
```

The output in `dist/conway-windows-store` contains a Store-upload `.msixbundle`
with self-contained x64 and ARM64 applications, individual `.msix` packages,
checksums, verification reports and listing artwork. The Store upload is unsigned;
Microsoft signs it after certification. Do not replace that upload with a locally
test-signed package. Existing released Linux archives and their checksums do not
change when the Windows source is updated.

## Icon and package checks

All 93 PNG package variants are exported directly from the 1254px transparent
master. They include seven display scales, taskbar target sizes, and dark/light
unplated variants. The largest tile export is 1240px, so no asset is upscaled.
The shell ICO contains 18 sizes through 256px. The WPF sidebar selects the largest
frame and downsamples it; the executable declares PerMonitorV2 DPI awareness.
Store listing icons are provided at 300px and 1080px. Inspect `icon-inspection.png`
at native size rather than enlarging the smaller samples.

The packaging script runs the simulation regression suite and verifies the
compiled embedded icon and tour bytes. On x64, it opens the compiled WPF window,
dismisses the real first-use tour, invokes Step/Undo/Redo/Clear/Start/Stop through
Windows UI Automation, checks autosave, and captures five 1600×1000 interfaces:
three themes with different simulation histories, pattern selection, and a finite
canvas. The separate **Capture Conway Windows screenshots** workflow produces
these images without rebuilding the complete Store bundle. The real compiled WPF
layout is rendered at 1600×1000 without padding or enlarging the runner's smaller monitor
image. They do not establish that real pointer input or installed MSIX behavior
works on a Windows 10/11 PC.

MakePri indexes icon variants. MakeAppx validation stays enabled; both packages are
unpacked and their payload hashes checked, and the bundle's inner package hashes
must match. `qa/package-report.json` records the SDK, hashes and remaining tests.
Windows App Certification Kit and Microsoft Store certification remain separate.

## Temporary remote desktop tests

The website repository has a separate private manual **Test Conway Windows
desktop** workflow. Its `NGROK_AUTH_TOKEN` secret is used only in the tunnel step.
The operator supplies one public client IP (`/32` or `/128`); ngrok restricts the
endpoint to that IP and Windows keeps Network Level Authentication enabled. The
workflow generates a random temporary login password and retains it only in the
private `conway-rdp-connection` artifact for one day, never in build logs or Git.
The desktop interval is bounded to 5–30 minutes and the tunnel is stopped afterward.

It attempts installation of a separately signed x64 MSIX test copy and records
the result. Hosted runners use Windows Server, so they cannot replace Windows
10/11 installation or certification tests. A desktop shortcut opens the installed
package when available, or the matching published native EXE otherwise.

The October 9 test installed the signed test copy successfully on the hosted
Windows Server runner. Remote access was blocked by ngrok error `ERR_NGROK_8013`:
the account needs card verification for TCP endpoints. No remote desktop or
pointer-input test was completed in that run.

For a Store update, upload the new bundle, use screenshots captured from the
Windows application, and review release notes and feature/requirement descriptions.
Keep the listing's published version unchanged until Microsoft approves the update.
