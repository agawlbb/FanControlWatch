# Apple Watch beta issue batch — 0.2.0

## October 20 follow-up — 0.5.2 (14)

- Addressed initial gray control readiness gates and transitional cover gating; preserved absolute displayed-state reversal, pending-conflict protection and speed draft timing.
- Addressed a locked-watch refresh obstacle by migrating connection accessibility to after first unlock, and reloading local selection before showing controls on foreground entry.
- Added a persistent push receipt/outbox history and Settings diagnostics. HA send attempts, relay/APNs results, watch receipts, save results and first app selection are correlated separately. Missing receipts remain unknown.
- HA's test harness uses explicit uv 0.13.4/Pillow 13.0.0 security overrides, validated in its own CI. This does not change deployed HA dependencies.

Implementation and remaining hardware checks: BUILD-14.md. Wear OS audit items remain deferred under its pause.

## Follow-up batch — 0.3.0 (6)

- Removed Cancel request and routine connection/music/request/failure captions.
- Confirmed states use teal, including OFF/CLOSED; requested/unconfirmed states
  remain gray. One-shot script, scene and horn dispatch never confirms completion.
- Driving climate is an absolute ON/OFF toggle with immediate gray projection.
- Driving uses a 2×2 garage/trunk/climate/horn layout. HA 0.5.1 adds an optional,
  explicitly configured horn role and capability-checked climate OFF.
- Horizontal swipes visit approved controls only for the current session. Leaving
  and reopening restores HA's selection. Swipe selection is never persisted or
  sent to HA; offscreen/prefetched panels never wake a vehicle.
- Pairing instructions and state labels remain; redundant operation prose does not.

Build and physical-watch verification are recorded in VERIFICATION.md.

| Report | Resolution |
| --- | --- |
| Optional Spotify player silently requires a playlist | HA 0.5.0 labels the dependency, explains how to skip Spotify, returns a playlist-specific error, and preserves submitted fields. |
| Exercise asks for an unused car color | Removed from its HA form. |
| Initial setup requires a fan | New Apple Watch pairing takes identity and addresses only. Fan Control is an optional panel in the HA panel manager. Existing device approvals remain compatible. |
| “Joes Ultra 4” becomes “Watch” and Wear OS | Failed forms preserve the name. HA device metadata updates when its name or authenticated platform changes. New pairing identifies watchOS; existing Apple Watch records repair on the new app's first config refresh. |
| Leave for Work asks for an unused car color | Removed from its HA form; Driving retains its color picker. |
| All panels show unnecessary title, clock and Connection button | Removed the title and Connection button; settings are available by long-press. **Remaining platform limitation:** watchOS continues drawing its system clock despite the supported hidden-overlays preference. Verified in the simulator. |
| Watch-face complication to open the active panel | Added Active Panel for supported circular, corner, inline and rectangular slots. It opens the app and refreshes the current HA selection; it sends no command. Build 3 checks HA selection before any settled-entry vehicle wake. |
| Routine “Requested” and “Confirmed by Home Assistant” text | Removed from panels; originating control outcomes and colors carry feedback. Failure/unknown state and separate music evidence remain explicit. Script dispatch never implies completion. |
| Bedroom fan repeatedly turns Unknown while open | Refresh errors and scene transitions no longer erase same-target observed state. Last observation stays gray and disabled until fresh state returns. Actual HA unknown/unavailable remains unknown. HA history at diagnosis contained ON/OFF states only. Physical-watch recovery check remains. |
| Select fan speed before ON is confirmed | Speed draft adjustment remains enabled during pending ON. The one-second quiet window is preserved and delivery is serialized behind power; cancellation and leaving discard queued speed. |

Verification and remaining watch/car checks are in VERIFICATION.md. No automated test establishes physical device behavior.

## Action receipts — 0.3.1 (8)

Only Leave for Work, Honk Horn, Start Exercise and Stop Exercise change:
ready teal command name → gray Activated on tap → teal Activated after an
authenticated HA command acknowledgment. Accepted receipts stay visible through
normal refreshes and temporary swipes during the foreground session; leaving
resets them. Rejection, timeout and ambiguous transport failure remain gray.
Receipt evidence does not populate observed state or claim physical completion.
An accepted Stop leaves HA's existing continuation and completion-based Driving
selection running. Fan tile, speed control, power/climate/cover toggles unchanged.


## October 20 batch - 0.4.0 (9)

- Untouched actions open teal and tappable without observed-state readiness gates.
- Gray power/climate/cover toggles remain tappable. Each tap reverses the displayed requested or last-known state using an explicit absolute command. Same-toggle pending work can be superseded; stale callbacks cannot change newer feedback. Speed adjustment keeps its existing quiet window.
- Passive background refresh requests HA selection and fan observations about every 15 minutes when watchOS permits. Requests disable watch cellular access while allowing expensive phone-proxy routes; physical phone-cellular versus watch-LTE verification remains. Background reads send no wake or control commands.
- Valid observed fan power/speed persists across sessions. Initial display uses exact watch/configuration cache in gray until fresh confirmation; unknown/unavailable responses retain cached fan state.
- Driving adds Podcast in a two-column, three-row grid. HA 0.5.2 supplies its optional script role; configure the Podcast script in HA.
- Exercise/Spotify troubleshooting remains paused. Existing behavior is unchanged.

Source d4f29cd9a3a05f8fce26d77e337069e759c0d5e1 passed 24 Swift tests, simulator and unsigned archive in run 39433912115. Signed archive/export/profile checks and upload passed in run 39433947519. HA source b3b1903 passed 172 tests locally; Android validateDebug passed. Hardware checks remain for scheduling, radio routing, rapid reversals, watch rendering and physical car behavior.
