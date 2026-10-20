# Watch command feedback

## Action receipt update — 0.3.1

Leave for Work, Honk Horn, Start Exercise and Stop Exercise use teal command
names when ready, gray Activated on tap, then teal Activated after authenticated
HA acceptance. Retain each receipt while actively displayed, through refreshes
and temporary swipes; reset on leaving or configuration change. Acceptance is
receipt evidence only, never physical completion. An acknowledged Stop must not
cancel HA's continuation; Driving selection still requires operation completion.
Stale callbacks and errors cannot acknowledge a tap. Do not modify toggles,
the fan tile or fan speed for this update.

## Apple Watch interaction update (October 19, 2026)

The user's current instructions supersede the older HA-only navigation and
verbose feedback rules below: swipe horizontally through approved panels/devices
for the foreground session only. Never persist that choice or change HA's
selection. A new foreground entry restores HA's selection. Only a displayed,
settled vehicle panel may wake. All confirmed states, including OFF and CLOSED,
use teal; pending, failed, unavailable and dispatch-only outcomes stay gray.
Do not display command status prose, Spotify evidence captions or Cancel request.
Keep the evidence internally without claiming completion. Driving has a 2×2 grid
for garage, trunk, climate toggle and the HA-configured one-shot horn button.

This is a required interaction rule for every current and future watch command,
on the main tile, separate Exercise tile, full-screen device/panel pages, and
any new watch screen or control.

- Immediately show the user's requested outcome on the existing control, before
  network work finishes. Use gray text/background while unconfirmed. Show the
  requested ON/OFF state, speed, lock/climate outcome, or REQUESTED for an action.
- Keep requested presentation separate from observed/confirmed state. Never
  write optimistic projections into the confirmed cache. Preserve one absolute
  intent through reads/retries so the action cannot invert after the tap.
- Only change the requested outcome to its confirmed color after evidence for
  that same watch, target, configuration and command. Receiving any response or
  finishing a request is not confirmation. Unavailable/unknown/mismatched state
  is not confirmation. Use CommandFeedback colors and VehicleFeedback semantics
  rather than equating an enabled/clickable button with confirmed success.
- Confirm power/speed/climate/lock from available observed state matching the
  request. Exercise Stop requires confirmation of all required HA operation
  steps. An HA observation is not independent proof of physical vehicle state.
- Scripts/scenes can confirm only dispatch acknowledgment: keep REQUESTED or
  Request accepted wording; never imply script completion. Spotify app launch,
  playback request and pause request do not prove playback or pause occurred.
  Report their own available evidence; vehicle confirmation cannot confirm music.
- While pending, disable conflicting command controls. Preserve fan speed draft
  adjustment during its existing one-second quiet window. Do not add retries to
  one-shot script, scene or music requests to obtain a prettier confirmation.
- Timeout, cancellation, rejection and ambiguous errors must never promote a
  requested outcome into confirmed colors. Show Not confirmed/unknown or replace
  it with a subsequent actual observed state. Keep terminal panel failures gray
  and distinguish retry availability from confirmation. Stale callbacks must not
  clear or recolor newer requests or another target. Leaving cancels ordinary
  UI work; existing explicit bounded foreground delivery may continue screen-off.
- Preserve external app handoffs such as Start opening Spotify; keep feedback on
  the originating control and don't introduce a waiting screen to show progress.

For command changes, check every surface that exposes the command and cover
immediate projection, delayed/mismatched/unavailable confirmation, successful
confirmation, failure/timeout/cancellation, and stale target/callback handling.
Run `gradlew.bat validateDebug` (APK, unit tests, lint) before delivery of watch
code changes. Report the tested version and remaining physical-watch checks.
Do not claim that automated tests verify actual WearOS rendering or car behavior.

## Driving panel

Driving uses HA-configured distinct garage/trunk cover roles, climate ON, and
vehicle wake/online roles. Keep its separate tile, active-panel main tile and
full-screen app page consistent. Initial trunk CLOSED is a gray presentation
assumption only: accept the first tap as an absolute OPEN intent, never invert
it after a late read, and never cache the assumption as observed state. Cover
commands dispatch at most once per tap, then poll for matching observed state.
Keep wake limited to displayed, settled vehicle entry only; configuration,
prefetch and background reads never wake the vehicle. Setup belongs in the
native HA panel manager, like Work Morning and Exercise, without hardcoded IDs.

Garage and trunk both use an initial gray CLOSED assumption with an immediate
absolute OPEN tap. Panel RGB identification colors are separate from gray/mint
command feedback. Show only the HA-selected device/panel in the app; do not expose watch-side
panel navigation. The identification bar is decorative and does not navigate. Only visible settled vehicle entry may send wake; command
delivery/retries, offscreen pages, prefetch and background work must not wake.


Driving-only identification bars: show the configured colored stripe only for Driving panels, on native tiles and full-screen controls. Fan, Work Morning and Exercise must not display identification bars. HA-only selection remains unchanged.
