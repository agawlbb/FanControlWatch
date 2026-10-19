# TestFlight beta 0.2.0

Independent Apple Watch client for the Fan Control Home Assistant integration. Requires watchOS 10 or newer and your own Home Assistant with the Fan Control HA integration. Pair using the watch's eight-digit code and verify the fingerprint in Home Assistant. Select devices and panels in HA.

Please check pairing, HA-selected device changes, fan power and six speeds, switches/lights, Work Morning, Exercise and Driving panels, delayed or unavailable state, cancellation, and wrist-down behavior. Requested outcomes stay gray until matching HA evidence. Script acknowledgments do not mean completion, and music acknowledgments do not prove playback.

Requires Fan Control HA 0.5.0 for the revised setup. Pair without choosing a fan, then add any panel in HA. Spotify player selection requires a playlist. Only Driving asks for a car color. Watch names and Apple Watch identification are preserved. Panels omit titles and the Connection button; long-press for settings. Gray/confirmed colors replace routine status captions. Transient read failures retain gray last-observed fan state; speed can be drafted while ON is pending. Add Active Panel in the watch-face complication editor to open the current HA-selected panel.

Address entry, Android-style screen-off foreground delivery and native Spotify media-session pause limitations remain. Real Apple Watch and vehicle testing is still required.

Source and license: https://github.com/agawlbb/FanControlWatch (AGPL-3.0-only).
Privacy: https://github.com/agawlbb/FanControlWatch/blob/main/PRIVACY.md
