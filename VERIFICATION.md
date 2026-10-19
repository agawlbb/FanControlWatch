# Verification and device checks

Apple port version 0.2.0 (build 2), based on Android 1.5.3; HA integration 0.5.0.

GitHub macOS CI compiles SwiftUI for watchsimulator and archives the watch-only distribution container. Core unit tests cover power/speed evidence, unavailable and mismatched responses, cover presentation assumptions, full Exercise Stop operation completion, pending/failure colors, request identity, encrypted response authentication, local/remote URL policy, safe read fallback, and no command fallback/replay after ambiguous transport failures.

All commands use the same full-screen control presentation. The Active Panel complication only opens the app; selection stays in HA and it sends no commands. One-shot command dispatch is never retried. Ordinary UI work cancels on leaving or inactive scene. Explicit Stop cancellation may send one bounded best-effort cancellation for the captured 36-character operation ID; it cannot recall completed physical actions.

Required physical Apple Watch checks:

- Pairing over local Wi-Fi and HTTPS; exact fingerprint and HA approval; encrypted credential survives app relaunch; forgetting and revocation.
- HA changes active device/panel during an in-flight refresh, speed draft, command and cancellation; verify no redirect or stale recoloring.
- Fan unknown initial state, OFF/ON, exact six speeds, one-second cumulative adjustments and leaving during draft.
- Light/switch/boolean unavailable, delayed/mismatched state, successful evidence, request rejection, lost response, timeout and cancellation.
- Scripts/scenes keep the originating action label gray with dispatch acknowledgment only; ambiguous failures never replay or imply completion.
- Pair without a fan, retain watch name on rejected submission, verify Apple Watch device model, then add/select/edit/remove each panel in HA. Spotify player without playlist must produce a field-specific error without clearing inputs. Only Driving asks for a car color.
- Open each supported complication family; verify the current HA-selected panel opens after selection changes and while previously unpaired. The complication must not send a command or store credentials.
- Keep the fan panel visible during a dropped refresh and recovery; last observed value stays gray and disabled, not replaced with UNKNOWN. Actual HA unknown/unavailable remains unknown. Draft speed immediately after ON, repeatedly adjust within one second, and confirm serialized delivery; cancellation/target changes must discard old drafts.
- Check uncluttered panels, hidden clock preference, long-press Connection settings, small/large watch sizes and accessibility.
- Work Morning battery/climate/script configured by HA, with no identification stripe.
- Exercise lock confirmation, stable Stop operation ID, pending/complete/failure/cancel outcomes and Spotify handoff. Music evidence remains separate from vehicle evidence.
- Driving garage/trunk initial gray CLOSED and absolute first OPEN; late reads cannot invert; moving states remain gray; dispatch at most once; climate ON; configured stripe only on Driving.
- Wake occurs once for a visibly settled vehicle entry, with no wake from configuration, command retry, background or hidden screen.
- Wrist-down, always-on display, connection changes, offline operation, small/large watch sizes, VoiceOver and larger text.

Automated checks do not establish actual watchOS rendering, local network permission behavior, music playback or physical vehicle behavior. Android `gradlew.bat validateDebug` (APK/unit tests/lint) also passes for the unchanged Android 1.5.3 baseline.
