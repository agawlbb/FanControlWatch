# TestFlight beta 0.2.0

Independent Apple Watch client for the Fan Control Home Assistant integration. Requires watchOS 10 or newer and your own Home Assistant with the Fan Control HA integration. Pair using the watch's eight-digit code and verify the fingerprint in Home Assistant. Select devices and panels in HA.

Please check pairing, HA-selected device changes, fan power and six speeds, switches/lights, Work Morning, Exercise and Driving panels, delayed or unavailable state, cancellation, and wrist-down behavior. Requested outcomes stay gray until matching HA evidence. Script acknowledgments do not mean completion, and music acknowledgments do not prove playback.

Requires Fan Control HA 0.5.0 for the revised setup. Pair without choosing a fan, then add any panel in HA. Spotify player selection requires a playlist. Only Driving asks for a car color. Watch names and Apple Watch identification are preserved. Panels omit titles and the Connection button; long-press for settings. Gray/confirmed colors replace routine status captions. Transient read failures retain gray last-observed fan state; speed can be drafted while ON is pending. Add Active Panel in the watch-face complication editor to open the current HA-selected panel.

Address entry, Android-style screen-off foreground delivery and native Spotify media-session pause limitations remain. Real Apple Watch and vehicle testing is still required.

Source and license: https://github.com/agawlbb/FanControlWatch (AGPL-3.0-only).
Privacy: https://github.com/agawlbb/FanControlWatch/blob/main/PRIVACY.md

## 0.3.0 (6)

Use horizontal swipes for temporary panel/device selection; leaving and reopening returns to HA's selection. Driving has a 2×2 garage, trunk, climate ON/OFF and horn grid. Confirmed ON/OFF/open/closed states use teal; commanded outcomes remain gray until matching evidence. Other confirmed controls stay teal while disabled by a pending command. Battery and speed readings follow the same observed-state colors. Routine operation, Spotify and failure captions and Cancel request were removed. Pairing instructions and essential control labels remain. Horn dispatch stays gray because HA acknowledgment does not establish that it sounded.

Install HA 0.5.1 for Driving climate OFF and the optional horn role. Both existing car panels on Joes Ultra 4 have their own horn roles configured. Physical-watch checks remain: swipe/vertical-scroll interaction, reopening selection, delayed confirmation, climate OFF, one-shot horn behavior, wrist-down cancellation and Spotify handoff. Automated tests/simulator images do not verify vehicle behavior.
