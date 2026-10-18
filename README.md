# Fan Control for Apple Watch

Independent watchOS 10+ SwiftUI client for the [Fan Control HA integration](https://github.com/agawlbb/FanControlHA), ported from [Android 1.5.3](https://github.com/agawlbb/FanControl/tree/841587d42c391afaac4df77621c7428dd250b2c9).

Licensed **AGPL-3.0-only**, matching the Android and Home Assistant projects. See LICENSE and NOTICE.md.

Encrypted RSA-2048/OAEP-SHA256 pairing and AES-256-GCM requests use the existing integration protocol. Credentials stay in this watch's unlocked, device-only Keychain. The watch displays only HA's active device or panel. Devices: fans with six exact speeds, lights, switches, input booleans, scripts and scenes. Panels: Work Morning, Exercise and Driving. Driving alone displays its configured identification stripe.

Requested outcomes appear immediately in gray. Confirmed HA evidence is separate from projection. Cover and script commands are dispatched at most once; errors remain unconfirmed. Exercise Stop uses a stable operation ID and requires HA operation completion. Vehicle wake occurs only after visible settled entry. Foreground commands cancel when leaving; this release does not claim Wear OS's foreground-service behavior while screen-off. Spotify handoff and HA music acknowledgment do not prove playback.

## Pairing

Enter your HA local or HTTPS address on the watch, choose Pair, then approve the eight-digit code in HA's native Fan Control configuration. Compare every fingerprint character. Configure devices, panels and active selection exclusively in HA. Remote addresses require HTTPS. This initial port uses address entry; Bonjour discovery and Smart Stack widgets are not implemented.

## Builds

GitHub Actions runs `swift test`, generates the Xcode project using XcodeGen, compiles for the watch simulator and archives for physical watchOS using GitHub macOS runners. Download the unsigned artifact for inspection; it cannot be installed through TestFlight until Apple signing is configured.

Version: 0.1.0 (build 1). Apple team: FKR675M7PM. Bundle ID: dev.fancontrol.watch.

Physical checks remain: local networking and pairing, revoked access, all configured device/panel actions, cancellation and target changes, wrist-down lifecycle, cover assumptions and delayed state, Spotify handoff/output, and actual vehicle behavior. Automated tests do not verify watch rendering or physical vehicle state.

## TestFlight release

The `TestFlight` workflow builds on GitHub's macOS runner, validates the watch-only container and embedded watch app, signs with automatic Apple provisioning, and optionally uploads to App Store Connect. Required repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`. Do not commit Apple keys, certificates, profiles or HA pairing credentials. A workflow can also execute in an existing trusted signing repository without moving its credentials here.

The distribution container is `dev.fancontrol.watch`; the independently running watch app is `dev.fancontrol.watch.watchkitapp`. App Store Connect app ID: 6824292561. Encryption compliance must be answered truthfully for the custom AES/RSA protocol before distributing a processed build.
