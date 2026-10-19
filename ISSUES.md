# Apple Watch beta issue batch — 0.2.0

| Report | Resolution |
| --- | --- |
| Optional Spotify player silently requires a playlist | HA 0.5.0 labels the dependency, explains how to skip Spotify, returns a playlist-specific error, and preserves submitted fields. |
| Exercise asks for an unused car color | Removed from its HA form. |
| Initial setup requires a fan | New Apple Watch pairing takes identity and addresses only. Fan Control is an optional panel in the HA panel manager. Existing device approvals remain compatible. |
| “Joes Ultra 4” becomes “Watch” and Wear OS | Failed forms preserve the name. HA device metadata updates when its name or authenticated platform changes. New pairing identifies watchOS; existing Apple Watch records repair on the new app's first config refresh. |
| Leave for Work asks for an unused car color | Removed from its HA form; Driving retains its color picker. |
| All panels show unnecessary title, clock and Connection button | Removed the title and Connection button; settings are available by long-press. **Remaining platform limitation:** watchOS continues drawing its system clock despite the supported hidden-overlays preference. Verified in the simulator. |
| Watch-face complication to open the active panel | Added Active Panel for supported circular, corner, inline and rectangular slots. It opens the app and refreshes the current HA selection; it sends no command. |
| Routine “Requested” and “Confirmed by Home Assistant” text | Removed from panels; originating control outcomes and colors carry feedback. Failure/unknown state and separate music evidence remain explicit. Script dispatch never implies completion. |
| Bedroom fan repeatedly turns Unknown while open | Refresh errors and scene transitions no longer erase same-target observed state. Last observation stays gray and disabled until fresh state returns. Actual HA unknown/unavailable remains unknown. HA history at diagnosis contained ON/OFF states only. Physical-watch recovery check remains. |
| Select fan speed before ON is confirmed | Speed draft adjustment remains enabled during pending ON. The one-second quiet window is preserved and delivery is serialized behind power; cancellation and leaving discard queued speed. |

Verification and remaining watch/car checks are in VERIFICATION.md. No automated test establishes physical device behavior.
