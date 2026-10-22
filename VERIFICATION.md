# Verification and device checks

## Passive push refresh — 0.5.1 (13), October 20, 2026

Prepared APNs registration through encrypted HA pairing, passive selected-panel
refresh, 1.5-second swipe-entry vehicle wake delay and immediate primary entry
after HA target verification. No cooldown. Config refreshes never create entry
wake. See PUSH-REFRESH.md for signing requirements and physical checks.

Source `679b5a9548fcfc3d8532ecadcbf83947e4ee3ca8` passed
[macOS CI](https://github.com/agawlbb/FanControlWatch/actions/runs/39499938418):
31 Swift tests, watchOS simulator compilation, simulator capture generation and
unsigned device archive. Source `9cbc0d0eed2ff3d57cce6d4ccae938e0c44c1948`
then passed the [signed build and upload](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39503517223),
including 31 tests and the exported production APNs entitlement check. Apple
processing and existing Internal-group availability
[passed](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39503517389):
0.5.1 (13) is VALID and IN_BETA_TESTING. See BUILD-13.md for full delivery proof.
Physical swipe timing, primary wake and passive APNs delivery
still require a real watch. Wear OS code and validation are untouched under the
development pause.
The hosted relay responds at https://coffeybean.com/FanControl/ and is configured
with a private production APNs key. Live HA 0.6.2 is loaded with native push
options enabled and authenticated relay checks passed without sending a push or
vehicle command. Real watch registration/delivery checks remain pending; no key
or relay secret is included in source or build artifacts.

## Pending source-only Driving Podcast update — October 20, 2026

Added the fifth Driving control, Podcast, in a two-column, three-row grid. Added the optional HA-configured script role, one-shot dispatch, and the existing per-action receipt path. Added source regression coverage for script role validation, unavailable/running scripts, vehicle-independent dispatch and action classification; updated the synthetic Driving preview. At the user's explicit request, no builds, tests, lint, simulator runs or validation were executed for this update. No deployment or real-watch/rendering/playback verification was performed. Wear OS sources were not changed for this update.

After build/deployment, check both Driving pages with their HA-selected podcast script, small/large watch layout and scrolling, immediate gray Activated, authenticated receipt, lost response/no replay, stale configuration/callbacks, and Spotify Joe's actual playback device. HA acceptance is dispatch evidence only.

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
- Check uncluttered panels, hidden clock preference, separate swipeable Settings page, small/large watch sizes and accessibility.
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

App Store Connect finished processing build 6 and its saved test notes were read back. Build ID: 3bee2eaa-19aa-4b29-8264-579ba8c17f4f. Assigned to the existing Internal group (one tester); the group's Builds page shows 0.3.0 (6) **Testing**. Previous available builds remain accessible. Local delivery proof: build/review030-build6/testflight-ready.png (ignored).

## 0.3.1 build 8 — October 19, 2026

Source: `67e068d5d8975a219cc29e23f009626adb4dba92`.
[macOS validation](https://github.com/agawlbb/FanControlWatch/actions/runs/39347937303)
passed on Xcode 26.6: 21 Swift tests, watchOS simulator build, installed-app
screenshots and unsigned archive. Inspected Driving ready/pending/accepted and
Exercise accepted screenshots: teal action name, gray Activated, then teal
Activated, without recoloring the unchanged state toggles. DEBUG-only synthetic
fixtures send no requests. Physical-watch receipt timing is not established.

The four new tests cover the action-only allowlist (excluding fan speed/toggles
and generic Run), pending/complete Stop acknowledgments versus rejected terminal
statuses, independent per-action receipt retention/reset, and stale callbacks,
other targets and late callbacks after session clearing. Acceptance is checked
only on an authenticated command response, never from a state/config poll.
Missing responses stay gray; Stop keeps its stable operation-ID delivery retries.
An acknowledged Stop no longer reaches the client's cancellation-on-return path;
HA continues its existing bounded operation and selects Driving after completion.
The separate one-shot music request and Spotify app handoff are preserved.

Compared against 0.3.0 (6): shared control(), entire device()/fan view, climate(),
cover(), fan speed adjust/delivery, Models.swift confirmation mappings,
Transport.swift and RequestedPresentation.swift are unchanged. The required root
`gradlew.bat validateDebug` passed after the final code change (Android 1.5.3
unchanged). HA 0.5.1 and HA automations/configuration were not modified.

Remaining physical-watch checks: all four actions' real acknowledgment timing,
receipt retention through refresh and temporary swipes, reset on leaving/reopening,
unavailable/rejected/ambiguous responses, repeat taps, Spotify handoff and the
accepted Stop continuation/Driving selection. These tests do not establish physical
vehicle, script or music completion; teal Activated represents HA acceptance only.

[Signed release](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39347941627)
used the existing approved signing repository and credentials, pinned to the exact
source above (tag `v0.3.1`). All 21 Swift tests passed again. The signed archive,
export, embedded container/watch/complication signature/profile checks and App Store
Connect upload succeeded at 8:37 PM EDT on October 19. Build 7 was an intermediate
build; build 8 preserves the existing separate music dispatch and stable Stop
operation-ID delivery behavior. TestFlight processing/group assignment is recorded
below after verification.

App Store Connect processing completed. Test notes were saved and read back; build 0.3.1 (8) was assigned to the existing Internal group (one tester). The group's Builds page visibly reports **Testing**. Delivery proof is in ignored build/review031-build8/testflight-ready.png. Previous tester builds remain available. Both repositories are clean after recording delivery.


## 0.4.0 / build 9 validation

HA Podcast source passed 172 tests locally. Swift tests, watch simulator compilation and archive are validated by the macOS workflow for the release commit. Required hardware checks: background delivery cadence with an active complication, phone cellular proxy versus watch LTE-only, cache display after termination, ON/OFF reversal during delayed receipt, stale responses after repeated taps, and HA Podcast script dispatch. Background reads never wake vehicles. Automated tests cannot prove radio routing, watch rendering or physical car behavior.

Verified 0.4.0 (9) source: d4f29cd9a3a05f8fce26d77e337069e759c0d5e1. macOS CI https://github.com/agawlbb/FanControlWatch/actions/runs/39433912115 passed 24 Swift tests, simulator captures and unsigned archive. Signed release https://github.com/agawlbb/coffey-table-recipes/actions/runs/39433947519 passed archive/export/signature/profile checks and upload. Reviewed Driving normal/pending simulator captures: Podcast fits the two-column grid (artifact 12270045760). Android validateDebug passed. TestFlight group assignment completed after App Store Connect reauthentication. HA 0.5.2 source is published; deployment is separate.

Build 0.4.0 (9), UUID 652a9f20-4d85-4e12-8982-54867fd5be56, is processed and Testing in the existing Internal group (1 tester), verified October 20, 2026. What to Test notes were saved. Existing builds remain available. Proof: build/review040-build9/testflight-ready.png.
# Exercise local player — 0.5.0 (10), October 20, 2026

Deployed October 20, 2026: HA 0.6.0 is loaded, and watch 0.5.0 (10) is VALID,
IN_BETA_TESTING in the existing Internal group. Source-only branch:
`codex/exercise-local-player`. No purchased audio is in source or build artifacts.
Draft PR:
https://github.com/agawlbb/FanControlWatch/pull/1.

Final macOS validation of source `0bdd8415649e906f12bf251e9209cd557b64cf24` passed:
28 Swift tests, watch simulator compilation/capture and unsigned device archive.
Run: https://github.com/agawlbb/FanControlWatch/actions/runs/39481637913.
The new encrypted-transfer fixture handles macOS URLSession's streamed POST
bodies. Reviewed waiting/playing and gray/teal Activated screenshots; explicit
44-point Exercise action areas keep Stop fully visible.

Signed archive/export, embedded signature/profile checks and upload passed:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/39487934220.
Apple processing, existing Internal assignment and test notes were verified:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/39488295868.
HA config check and restart succeeded; Fan Control returned loaded. Deployed
Python compilation passed. Four test MP3 files were uploaded privately to the
HA config music folder and their SHA-256 hashes matched the local originals.
No vehicle commands were sent for deployment verification. On the watch, install
build 10, then Connection settings > Sync exercise music; watch sync/playback
has not been performed remotely.

HA 0.6.0 source: 183 integration tests passed, including new encrypted private
music transfer, replay rejection, watch/panel authorization, local Stop with
rounded temperature, partial/ambiguous dispatch, one-minute mismatch, unavailable
state, config change, revoked owner, and successful silent verification. Existing
legacy Exercise tests pass unchanged. Wear OS code/builds/tests were not touched.

No paid audio is required for any automated check. Swift test additions
cover route gating, manifest validation, bounded larger encrypted music responses
and Exercise receipt rejection/acceptance semantics.

Pending on Ultra 4/watchOS 27.0.1: private music sync and offline playback;
Joseph's Buds2 Pro pairing and route identity after re-pair; delayed headset
connection; built-in speaker opt-in and session reset; route loss without an
audible speaker fallback; call interruptions; previous/pause/next and ordered
repeat; select native volume control and adjust Crown; wrist-down and screen
navigation; Start lock/Stop unlock+climate with gray then teal feedback; HA
notification at one minute for mismatch/offline; target change/revocation and
Stop continuation/Driving selection. HA persistent notifications do not provide
phone/watch push without separate notification routing. Automated checks do not
verify actual watch rendering, audible playback or physical car behavior.

## 0.5.0 (11): separate swipeable Settings page

The deprecated context-menu route did not work on the user's watch. User chose
a separate Settings page in the horizontal panel sequence, with Connection
settings and Sync exercise music, instead of a button on each control panel.
Settings remains reachable with one configured panel, wraps in both directions,
and is never saved as HA's active selection. It stops visible-panel work and
returns no device, so entry does not read/wake a car. Opening Connection settings
and returning preserves the Settings page; a new foreground entry resets to HA.

Source `0ef70ae0b1ded5e5a6a96bc47b0dc7e5a6e0c256`: 31 Swift tests passed,
including three navigation tests for one/multiple/no configured panels. Simulator
compilation/screenshots and unsigned archive passed; reviewed Settings and
Exercise captures. Settings menu fits; Exercise retains its existing layout.
CI: https://github.com/agawlbb/FanControlWatch/actions/runs/39489915641.
Signed archive/export/signature/profile validation and upload passed:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/39490119699.
Apple confirmed build 11 VALID, IN_BETA_TESTING in the existing Internal group:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/39490119809.

HA 0.6.0 and the four private test tracks are unchanged. No vehicle command was
sent for validation. Physical-watch checks: swipe from either direction to
Settings, open/return from Connection settings, sync music to completion, confirm
HA-selected entry after reopening, and verify the remaining audio/vehicle checks.
