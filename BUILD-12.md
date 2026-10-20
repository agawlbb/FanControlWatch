# Exercise fixes — 0.5.0 (12)

Source: `11e61486cdb6de7ee3b2b60437e1c52db4e7eae8`.
CI: https://github.com/agawlbb/FanControlWatch/actions/runs/39495598296.

All 31 Swift tests, simulator compilation/captures and unsigned device archive
passed. Reviewed waiting, playing, gray Activated, teal Activated and Settings
captures: Start/Stop anchors match across all Exercise states and native volume
is separate from playback controls. This is simulator evidence only.

- Navigation starts with HA's active panel, then other approved controls, then
  Settings. The ends do not wrap; Settings never separates control panels.
- Exercise uses fixed top/bottom Start and Stop buttons and a flexible middle.
  Waiting/headset/speaker messages occupy the same middle as playback controls.
- Previous, play/pause and next have their own row. Native system volume has a
  separate row and takes Crown focus while playback is displayed on the active
  Exercise page. Leaving the page releases focus.
- Stop sends its stable operation ID to HA without a preliminary vehicle-state
  readiness read. HA 0.6.1 delivers unlock and climate-on independently and
  requests 63°F best effort. Available matching unlock/climate-on observations
  complete Stop; temperature failure/mismatch does not block completion.
- Start dispatches once and waits for matching HA lock evidence before its
  Activated receipt becomes teal. Stop waits for HA operation completion.
  Pending, errors, timeouts and stale targets remain unconfirmed/gray.
- A local one-minute unconfirmed notification is scheduled at the tap,
  independent of network success or view lifetime. Allow notifications when
  watchOS asks. Matching confirmation cancels that request. A newer command
  supersedes the same target's earlier alert. HA separately checks observed
  vehicle state at one minute and creates a persistent HA notification if needed.

HA 0.6.1 source `91c8f2914804dcbe2ee86a83f25d67669107cef0` passed 187 integration
tests and Python compilation. Its deployed source was read back and verified;
HA reported the integration loaded after restart. Private audio is neither
committed nor included in CI artifacts.

Physical checks still required on Ultra 4/watchOS 27.0.1: Crown volume without
tapping volume first; headset/speaker routing; Start lock and Stop unlock plus
climate delivery; teal feedback after delayed HA evidence; one-minute notification
with screen inactive and permission granted; and completion/Driving selection.
Automated tests establish neither audible playback nor physical car behavior.
