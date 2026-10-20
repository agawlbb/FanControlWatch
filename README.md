# Fan Control for Apple Watch

Independent watchOS 10+ SwiftUI client for the [Fan Control HA integration](https://github.com/agawlbb/FanControlHA), ported from [Android 1.5.3](https://github.com/agawlbb/FanControl/tree/841587d42c391afaac4df77621c7428dd250b2c9).

Licensed **AGPL-3.0-only**, matching the Android and Home Assistant projects. See LICENSE and NOTICE.md.

Encrypted RSA-2048/OAEP-SHA256 pairing and AES-256-GCM requests use the existing integration protocol. Credentials stay in this watch's unlocked, device-only Keychain. The watch opens HA's active device or panel. Horizontal swipes temporarily visit other approved controls; reopening restores HA's selection. Devices: fans with six exact speeds, lights, switches, input booleans, scripts and scenes. Panels: Fan Control, Work Morning, Exercise and Driving. Driving alone displays its configured identification stripe.

Requested outcomes appear immediately in gray. Confirmed HA evidence is separate from projection. Cover and script commands are dispatched at most once; errors remain unconfirmed. Exercise Stop uses a stable operation ID and requires HA operation completion. Vehicle wake occurs only after visible settled entry. Foreground commands cancel when leaving; this release does not claim Wear OS's foreground-service behavior while screen-off. Spotify handoff and HA music acknowledgment do not prove playback.

## Pairing

### Pending source update: Driving Podcast action

Driving now lays out Garage / Trunk, Climate / Honk Horn, and Podcast / an empty cell in two columns and three rows. In HA's native Driving panel editor, select the optional **Podcast script** (for example `script.baby_blue_podcast_play`). The watch sends that configured script once per tap, without requiring the car to be awake or selecting a Spotify device. Gray Activated followed by teal Activated acknowledges HA dispatch only; it does not confirm script completion or podcast playback. Existing panels remain valid without a podcast script. This source update has not been built, tested or deployed, at the user's request. Wear OS remains paused and unchanged by this update.

Enter your HA local or HTTPS address on the watch, choose Pair, then approve the eight-digit code in HA's native Fan Control configuration. Compare every fingerprint character. Configure devices, panels and the default active selection in HA. Remote addresses require HTTPS. This client uses address entry; Bonjour discovery is not implemented. The Active Panel complication is available in compatible watch-face slots.

## Builds

GitHub Actions runs `swift test`, generates the Xcode project using XcodeGen, compiles for the watch simulator and archives for physical watchOS using GitHub macOS runners. Unsigned CI artifacts are for inspection. The signed release is distributed through TestFlight.

Version: 0.3.1 (build 8). Apple team: FKR675M7PM. Bundle ID: dev.fancontrol.watch.

Version 0.2.0 requires HA integration 0.5.0 for fan panels and fan-free initial setup. Pair first with a watch name and address, then use Manage watch panels to add Fan Control, Exercise, Driving or Work Morning. Spotify player selection requires a playlist; both can be left blank. Only Driving asks for an identification color. Existing device configurations remain supported.

Panels omit the title and Connection button. Long-press the panel to open Connection settings. The app requests hidden system overlays; watchOS controls the final visibility of its own clock. Gray requested outcomes and teal confirmed states (including OFF/CLOSED) replace routine status captions. No Cancel request or Spotify/dispatch status text is shown. Driving uses a 2×2 garage, trunk, climate toggle and horn grid; HA 0.5.1 supplies climate OFF and the optional horn role. Panel actions use teal command names when ready, gray Activated after a tap, then teal Activated after HA accepts the command. This receipt stays for the displayed session; it does not claim physical completion. Generic script/scene Run feedback stays unchanged. A failed refresh retains only the same target's last observation, gray and disabled until a fresh read. Speed adjustments can be drafted while ON is pending and are delivered serially after its one-second quiet window.

Add the **Active Panel** complication in the watch face editor. Circular, corner, inline and rectangular slots are supported where the face permits them. Tapping opens the app's current HA-selected panel and refreshes configuration; the complication stores no credentials or stale panel selection.

Physical checks remain: local networking and pairing, revoked access, all configured device/panel actions, cancellation and target changes, wrist-down lifecycle, cover assumptions and delayed state, Spotify handoff/output, and actual vehicle behavior. Automated tests do not verify watch rendering or physical vehicle state.

## TestFlight release

The `TestFlight` workflow builds on GitHub's macOS runner, validates the watch-only container and embedded watch app, signs with automatic Apple provisioning, and optionally uploads to App Store Connect. Required repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `IOS_DEVELOPMENT_CERT_P12`, `IOS_DEVELOPMENT_CERT_PASSWORD`. Do not commit Apple keys, certificates, profiles or HA pairing credentials. A workflow can also execute in an existing trusted signing repository without moving its credentials here.

The distribution container is `dev.fancontrol.watch`; the independently running watch app is `dev.fancontrol.watch.watchkitapp`. App Store Connect app ID: 6824292561. SIGNING-REVIEW.md documents the approved OS-provided cryptography declaration.


Version 0.1.0 build 1 was compiled, signed, verified and accepted by App Store Connect on October 18, 2026 using GitHub macOS runners. Release source: `233cac2b77bff814ae8bbb6ebce928ffa42b1b14`. The [successful release run](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39161828320) reused credentials within the existing trusted signing repository; no credentials were copied here. All 13 core tests passed. Physical Apple Watch and Home Assistant/vehicle checks in VERIFICATION.md remain outstanding.

Version 0.2.0 build 2 was signed, verified and uploaded on October 19, 2026. Release source: `9a8c925197eeafbf5b17e90479de02a2536c6ef0`, tagged `v0.2.0`; [successful macOS release](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39329001573). All 16 core tests passed. The embedded Active Panel complication is `dev.fancontrol.watch.watchkitapp.activepanel`. The same existing signing repository and credentials were reused. [ISSUES.md](ISSUES.md) records every reported issue, its resolution and the remaining system-clock limitation.

Build 3 supersedes build 2 and refreshes HA's current selection before the settled-entry vehicle wake, so a complication tap does not wake the previously cached car before configuration is refreshed. Source: `7d9bd4ec8a7d3adcd2086b0889f0aef65247c575`, tag `v0.2.0-build3`; [successful macOS release and upload](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39330236334). All 16 core tests and signed archive/export/profile checks passed again.

Build 1 has completed processing and is assigned to the manual Internal group. The account holder's tester invitation is available through TestFlight. Initial release limitations and physical checks are listed in BETA.md and VERIFICATION.md.


Version **0.3.0 build 6** is processed and Testing in the existing Internal TestFlight group. Exact source: 85331dd5b196b709d1095ec43a00f8d5ed88c596, tag v0.3.0. The macOS release/upload run is https://github.com/agawlbb/coffey-table-recipes/actions/runs/39341077559; 17 core tests, signed archive/export and embedded profile/signature checks passed. HA 0.5.1 is deployed with both car horn roles configured. See ISSUES.md and VERIFICATION.md for changes, simulator evidence and remaining hardware checks.

Version **0.3.1 build 8** is processed and Testing in the existing Internal TestFlight group. Only Leave for Work, Honk Horn, Start Exercise and Stop Exercise gain session-retained Activated receipt feedback. Fan tile, speed controls and toggles remain unchanged. Source: 67e068d5d8975a219cc29e23f009626adb4dba92, tag v0.3.1; signed macOS release: https://github.com/agawlbb/coffey-table-recipes/actions/runs/39347941627. All 21 core tests, simulator/archive and signing/profile checks passed. Physical-watch acknowledgment, reset and handoff checks remain in VERIFICATION.md.


Version 0.4.0 (build 9) adds passive background selection/fan refresh (requested every 15 minutes, watchOS scheduling permitting), persisted observed power/speed, and gray cached state on entry. Background networking disallows the watch cellular radio but permits expensive phone-proxy routes; the phone-cellular path needs hardware validation. Untouched actions open teal and tappable. Gray toggles can be reversed with explicit absolute commands, including while the previous request is pending. Older callbacks cannot confirm a newer tap. Fan speed's existing quiet window is unchanged. Driving includes an HA-configured Podcast script action in a two-column grid. Exercise and Spotify behavior are otherwise unchanged.

0.4.0 (9) signed build and upload succeeded: https://github.com/agawlbb/coffey-table-recipes/actions/runs/39433947519. Source d4f29cd9a3a05f8fce26d77e337069e759c0d5e1 passed 24 Swift tests and simulator/archive checks. See ISSUES.md and VERIFICATION.md for hardware checks and TestFlight assignment status.
