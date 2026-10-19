# Apple Watch beta issue batch — 0.2.0

## Follow-up batch — 0.3.0 (4)

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
