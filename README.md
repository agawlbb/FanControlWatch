# Fan Control for iPhone and Apple Watch

**Current TestFlight release:** 0.9.1 (19), with HA 0.10.0 and the updated
command outcome relay. See [release evidence](RELEASE.md) and
[the implementation record](UNRELEASED-CORRECTIONS.md).

Opening a nonvehicle control makes one bounded authenticated HA state read,
without a command tap or phone. Local command alerts reconcile saved timers on
recovery, suppress obsolete callbacks and avoid duplicate notifications. The
release passed 63 Swift tests, both simulator builds and signed upload checks.

Independent watchOS 10+ SwiftUI client for the [Fan Control HA integration](https://github.com/agawlbb/FanControlHA), ported from [Android 1.5.3](https://github.com/agawlbb/FanControl/tree/841587d42c391afaac4df77621c7428dd250b2c9).

## iPhone companion — 0.6.0 (15)

The iOS 17+ companion manages fixed watch swipe order, preferred headset, and
imported MP3/M4A/AAC exercise music. Add/reorder/remove tracks, then Sync for
offline watch playback. Files are hash checked and the previous playlist remains
playable until its complete replacement is installed.

Pair the watch with HA as before, then open both apps and Link watch on iPhone.
Requires HA 0.7.0 and its updated push relay. The phone receives a separate
observation/preferences key; the watch command key stays on the watch. Unlink
phone revokes only that key. HA watch revocation revokes both.

Routine refresh belongs to the phone: APNs, opportunistic background refresh,
and 15-second refresh while the phone app is visible. The watch has no routine
HA polling. It immediately displays its saved panel/states and asks the phone
for its cache on entry. Without the phone, saved controls, direct HA commands,
command-confirmation reads, visible settled-entry wake and offline music remain
available. Cached states stay gray and tappable; snapshots cannot confirm a
watch command. iOS background execution/delivery remains opportunistic.

The Settings swipe page is removed; hold a watch page for setup/recovery. HA
selects the opening panel until a swipe saves a local default. That default survives reopening until another swipe or an HA selection/configuration revision; phone ordering controls swipe order without changing
selection. Phone diagnostics show cache time and watch acknowledgment; HA
retains correlated push attempts, phone receipt/save and watch-save events.

## Pairing and controls

Enter the HA local or HTTPS address on the watch, choose Pair, then approve its
eight-digit code and compare the full fingerprint in HA's native Fan Control
configuration. Configure devices, panels and opening selection in HA. Remote
addresses require HTTPS. Add the Active Panel complication in the watch face editor.

Fans expose power and six speeds; approved lights, switches, booleans, scripts
and scenes retain their controls. Driving has Garage, Trunk, Climate, Horn and
optional Podcast. Exercise uses private offline audio and headset routing. Stop
requests unlock, climate on and 63 F; local-mode completion requires available
unlock/climate evidence, with temperature best effort. HA then selects the unique
matching Driving panel. Receipt colors never prove physical state or playback.

## Development and releases

For instructions to run tests, build on GitHub's Mac runner, configure Apple
signing credentials, and publish to internal TestFlight directly from this
repository, see [GitHub builds and TestFlight setup](GITHUB-TESTFLIGHT.md).

Current version: **0.9.1 (19)**; iOS 17+, watchOS 10+, HA 0.10.0. Published to the existing Internal TestFlight group.
`swift test` runs core regression tests. XcodeGen uses `project.yml` to generate
the iPhone, watch and complication targets. Existing GitHub workflows compile
simulators/archive on main pushes and build/upload TestFlight only by explicit
dispatch. Inspect workflow triggers before pushing; do not run release workflows
for documentation maintenance.

[Release evidence and remaining hardware checks](RELEASE.md),
[privacy](PRIVACY.md), and [signing/encryption policy](SIGNING-REVIEW.md).
Historical release tags and Git history retain earlier release source; old setup
instructions are superseded by this companion workflow. Licensed AGPL-3.0-only;
see LICENSE and NOTICE.md. Never commit keys, certificates, pairing secrets or audio.

## HA-owned commands - 0.8.0 (17)

Requires HA integration 0.9.0. Every HA control saves an absolute intent and schedules
background submission before monitoring. HA durably accepts it and owns readiness,
bounded wake, safe retries and confirmation, including recovery after HA restart.
Leaving the watch screen stops monitoring without cancelling delivery; reopening
reconciles the same operation. Fan-speed debounce is HA-owned. One-shot actions
are never blindly replayed after an ambiguous response.

Delivery allows three minutes plus a 15-second read-only final check. Expected
wake/retry delays do not trigger one-minute Exercise alerts; absent evidence stays
**not confirmed**. Scripts/scenes/music receipts prove dispatch acceptance only.
Local music stays watch-owned; phone snapshots and passive reads never wake cars.
Existing pairings are preserved. See [the delivery contract](COMMAND-DELIVERY.md).
