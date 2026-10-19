# Fan Control for Apple Watch

Independent watchOS 10+ SwiftUI client for the [Fan Control HA integration](https://github.com/agawlbb/FanControlHA), ported from [Android 1.5.3](https://github.com/agawlbb/FanControl/tree/841587d42c391afaac4df77621c7428dd250b2c9).

Licensed **AGPL-3.0-only**, matching the Android and Home Assistant projects. See LICENSE and NOTICE.md.

Encrypted RSA-2048/OAEP-SHA256 pairing and AES-256-GCM requests use the existing integration protocol. Credentials stay in this watch's unlocked, device-only Keychain. The watch displays only HA's active device or panel. Devices: fans with six exact speeds, lights, switches, input booleans, scripts and scenes. Panels: Fan Control, Work Morning, Exercise and Driving. Driving alone displays its configured identification stripe.

Requested outcomes appear immediately in gray. Confirmed HA evidence is separate from projection. Cover and script commands are dispatched at most once; errors remain unconfirmed. Exercise Stop uses a stable operation ID and requires HA operation completion. Vehicle wake occurs only after visible settled entry. Foreground commands cancel when leaving; this release does not claim Wear OS's foreground-service behavior while screen-off. Spotify handoff and HA music acknowledgment do not prove playback.

## Pairing

Enter your HA local or HTTPS address on the watch, choose Pair, then approve the eight-digit code in HA's native Fan Control configuration. Compare every fingerprint character. Configure devices, panels and active selection exclusively in HA. Remote addresses require HTTPS. This client uses address entry; Bonjour discovery is not implemented. The Active Panel complication is available in compatible watch-face slots.

## Builds

GitHub Actions runs `swift test`, generates the Xcode project using XcodeGen, compiles for the watch simulator and archives for physical watchOS using GitHub macOS runners. Unsigned CI artifacts are for inspection. The signed release is distributed through TestFlight.

Version: 0.2.0 (build 3). Apple team: FKR675M7PM. Bundle ID: dev.fancontrol.watch.

Version 0.2.0 requires HA integration 0.5.0 for fan panels and fan-free initial setup. Pair first with a watch name and address, then use Manage watch panels to add Fan Control, Exercise, Driving or Work Morning. Spotify player selection requires a playlist; both can be left blank. Only Driving asks for an identification color. Existing device configurations remain supported.

Panels omit the title and Connection button. Long-press the panel to open Connection settings. The app requests hidden system overlays; watchOS controls the final visibility of its own clock. Gray outcomes and confirmed colors replace routine request/confirmation captions. A failed refresh retains only the same target's last observation, gray and disabled until a fresh read. Speed adjustments can be drafted while ON is pending and are delivered serially after its one-second quiet window.

Add the **Active Panel** complication in the watch face editor. Circular, corner, inline and rectangular slots are supported where the face permits them. Tapping opens the app's current HA-selected panel and refreshes configuration; the complication stores no credentials or stale panel selection.

Physical checks remain: local networking and pairing, revoked access, all configured device/panel actions, cancellation and target changes, wrist-down lifecycle, cover assumptions and delayed state, Spotify handoff/output, and actual vehicle behavior. Automated tests do not verify watch rendering or physical vehicle state.

## TestFlight release

The `TestFlight` workflow builds on GitHub's macOS runner, validates the watch-only container and embedded watch app, signs with automatic Apple provisioning, and optionally uploads to App Store Connect. Required repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `IOS_DEVELOPMENT_CERT_P12`, `IOS_DEVELOPMENT_CERT_PASSWORD`. Do not commit Apple keys, certificates, profiles or HA pairing credentials. A workflow can also execute in an existing trusted signing repository without moving its credentials here.

The distribution container is `dev.fancontrol.watch`; the independently running watch app is `dev.fancontrol.watch.watchkitapp`. App Store Connect app ID: 6824292561. SIGNING-REVIEW.md documents the approved OS-provided cryptography declaration.


Version 0.1.0 build 1 was compiled, signed, verified and accepted by App Store Connect on October 18, 2026 using GitHub macOS runners. Release source: `233cac2b77bff814ae8bbb6ebce928ffa42b1b14`. The [successful release run](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39161828320) reused credentials within the existing trusted signing repository; no credentials were copied here. All 13 core tests passed. Physical Apple Watch and Home Assistant/vehicle checks in VERIFICATION.md remain outstanding.

Version 0.2.0 build 2 was signed, verified and uploaded on October 19, 2026. Release source: `9a8c925197eeafbf5b17e90479de02a2536c6ef0`, tagged `v0.2.0`; [successful macOS release](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39329001573). All 16 core tests passed. The embedded Active Panel complication is `dev.fancontrol.watch.watchkitapp.activepanel`. The same existing signing repository and credentials were reused. [ISSUES.md](ISSUES.md) records every reported issue, its resolution and the remaining system-clock limitation.

Build 3 supersedes build 2 and refreshes HA's current selection before the settled-entry vehicle wake, so a complication tap does not wake the previously cached car before configuration is refreshed. Source: `7d9bd4ec8a7d3adcd2086b0889f0aef65247c575`, tag `v0.2.0-build3`; [successful macOS release and upload](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39330236334). All 16 core tests and signed archive/export/profile checks passed again.

Build 1 has completed processing and is assigned to the manual Internal group. The account holder's tester invitation is available through TestFlight. Initial release limitations and physical checks are listed in BETA.md and VERIFICATION.md.

