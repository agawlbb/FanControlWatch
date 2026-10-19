# Verification and device checks

Apple port version 0.2.0 (build 3), based on Android 1.5.3; HA integration 0.5.0.

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

October 19, 2026: release source `9a8c925197eeafbf5b17e90479de02a2536c6ef0` passed all 16 Swift core tests, signed device archive, App Store export, strict signature/team/profile checks for the container, watch app and complication, and upload on GitHub macOS runners. Release run: https://github.com/agawlbb/coffey-table-recipes/actions/runs/39329001573. HA 0.5.0 passed 169 unit/integration tests, Python compilation and the isolated real HA 2026.10.1 runtime check: https://github.com/agawlbb/FanControlHA/actions/runs/39329061312. Live HA restarted successfully on 0.5.0 with no Fan Control system-log errors; its saved watch name was repaired through the official options flow.

Simulator inspection confirms watchOS continues displaying the system clock despite `.persistentSystemOverlays(.hidden)`. This part of the requested panel cleanup remains a platform limitation; no private API is used to suppress it.

Replacement build 3 (`7d9bd4ec8a7d3adcd2086b0889f0aef65247c575`) refreshes HA selection before visible entry wake, and suppresses that wake when configuration/state refresh failed or the generation changed. All 16 tests, signed archive/export/profile verification, and upload passed: https://github.com/agawlbb/coffey-table-recipes/actions/runs/39330236334. Android `validateDebug` passed again after this final lifecycle correction.

App Store Connect processed 0.2.0 (3) and its Internal group assignment was verified with one tester. What to Test notes are saved. Build ID: `60a78b9d-99bd-44ee-a362-c0901305578c`. Earlier builds remain available. Installing and opening build 3 is still required to verify migration of the existing Apple Watch's platform label and the physical checks above.

## 0.3.0 build 6 — October 19, 2026

Release source: `85331dd5b196b709d1095ec43a00f8d5ed88c596` (`v0.3.0`).
[macOS simulator and archive validation](https://github.com/agawlbb/FanControlWatch/actions/runs/39341067529) passed on Xcode 26.6: 17 core tests, watchOS simulator compilation, installed-app screenshots and unsigned archive. Simulator images were inspected for the 2×2 Driving grid, teal confirmed CLOSED/OPEN/ON, gray pending Climate OFF with unrelated confirmed controls remaining teal, and Exercise without status prose or Cancel request. Fixtures are DEBUG-only, synthetic and make no network requests.

[Signed release and upload](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39341077559) used the existing approved signing repository and credentials, pinned to that exact source. All 17 tests passed again; archive/export, container/watch/complication profile and signature checks passed. Apple accepted the upload at 7:30 PM EDT. The final source includes teal battery readings and gray unavailable values. Intermediate builds 4 and 5 are superseded by build 6.

HA 0.5.1 source `ca0cb268b384df7b0703419aac6627de2e5b4644` (`v0.5.1`) passed 171 tests and Python compilation locally and in [CI](https://github.com/agawlbb/FanControlHA/actions/runs/39340630372), plus the isolated real Home Assistant 2026.10.1 runtime check. The existing manually-disabled HA workflow setting was restored after this check. HACS installed the exact tested source; HA restarted and reports 0.5.1 loaded with no Fan Control system-log errors. Both Apple Watch Driving panels have their respective horn roles saved and verified in the native HA form. Both climate entities advertise explicit ON/OFF support. HA's selected panel remains device controls. No fan, car, cover or horn command was issued as a deployment test.

The required root `gradlew.bat validateDebug` passed after the final watch code change (Android 1.5.3 unchanged). Code review covered session-only selection, reset on foreground entry, exact configuration revalidation, cancellation/generation checks, gray terminal/dispatch outcomes, and settled visible entry wake. Automated tests do not establish physical-watch behavior. Remaining checks: real left/right gestures versus scrolling, reopen/reset and wrist-down lifecycle, delayed/mismatched state, actual climate OFF/horn/cover behavior, Spotify handoff, fan speed quiet window and network recovery.
