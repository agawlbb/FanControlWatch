# Command feedback and reliability release - 0.9.0 (18), October 25, 2026

Published to the existing **Internal** TestFlight group. Apple build
`59d77956-c358-4b1a-b0d4-1c0ce47b933f` is `VALID`, not expired and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testers, beta review
submission or App Store release were created.

Signed source: `a1161318e91ea0c54c956ecd963a09b4a8321aae`.
Phone, watch and complication all report 0.9.0 (18). Later documentation commits
do not change that signed source. HA 0.10.0 and the matching outcome relay are
installed and verified; both existing pairings were preserved.

## Changes

- Every control immediately projects the requested outcome in gray and turns teal
  on authenticated HA ownership, including Climate. HA execution and observation
  continue independently after leaving the watch screen. Terminal failures return
  gray. Existing controls have no separate command status messages.
- Foreground/background acknowledgment and reopening share persisted receipts;
  stale snapshots/callbacks cannot overwrite newer requests. Visible vehicle entry
  performs bounded wake/readiness refresh. Cold climate presents gray OFF so the
  first tap remains absolute ON despite stale cached ON.
- Generic command failures use a dedicated watch notification destination, separate
  from phone snapshots. Expected wake/retry delays remain silent; missing handoff
  has a local not-confirmed notification fallback after 195 seconds plus 30 seconds
  transport grace. Notification wording is separate from control presentation.
- Bounded diagnostics correlate tap, upload, HA arrival/acceptance, wake, dispatch,
  observed outcome, feedback display and notification transport. Future-command
  requirements are recorded in both repositories' AGENTS.md.

## Validation and evidence

50 Swift tests and unsigned iPhone/watch simulator builds passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/40199880630

The release repeated 50 Swift tests and passed signed archive/export, deep
signature verification, production APNs entitlements, three bundle/version checks,
upload, Apple processing and existing internal group access:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/40242439379

257 HA/relay/deployment regression tests passed locally. Matching runtime sources
passed real-HA, PHP, compilation and package checks:
https://github.com/agawlbb/FanControlHA/actions/runs/40242073803
Relay deployment/readback passed:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/40242258723
Live HA source hashes, loaded version and pairing preservation passed after restart.
See FanControlHA `DEPLOYMENT-0.10.0.md` for backups and rollback.

IPA SHA256: `61271a1f6dc98d1d7d4bf7935f5f8ba821128796ae6023b9f776b4cb07edd1c2`.
Local signed IPA, Apple processing record, logs and branch recovery are preserved
under `build/corrections-release/`. The temporary signing/relay branch was retired
with an exact-head lease after recovery verification. CTR main advanced under its
owner and was not changed by this release.

Physical watch/car checks remain: cellular-only swipe/tap/immediate exit,
sleeping-car wake/climate, notification permission and delivery, opposite intents,
HA restart and observed-state freshness. Automated checks do not prove paired
watch rendering, OS scheduling, actual notifications or physical car outcomes.

---

# Durable command delivery release - 0.8.0 (17), October 24, 2026

Published to the existing **Internal** TestFlight group. Apple build
`235e769a-793d-4406-a96c-ca0fd44c7b66` is `VALID`, not expired and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testers, beta review
submission or App Store release were created.

Signed source: `aff112a6b1b2a5ed7e2017e83495b4efccd9fa73`.
Phone, watch and complication all report 0.8.0 (17). The released binary remains pinned to that source.
Newer unshipped work is documented in [UNRELEASED-CORRECTIONS.md](UNRELEASED-CORRECTIONS.md).
HA 0.9.0 was deployed and loaded; both existing pairings were preserved.

## Changes

- Every HA control now saves one absolute intent in the watch keychain outbox and
  schedules background submission before monitoring. Navigation and wrist-down
  cancel UI observation only; accepted commands remain HA-owned.
- HA persists acceptance and dispatch boundaries, resumes operations after restart
  within the original deadline, retries safe desired states and never blindly
  replays ambiguous cover/horn/script/scene actions.
- Fixed the first-tap audit gaps: transient reads no longer gate dispatch, unrelated
  configuration does not block a valid captured target, generic services do not
  block operation acceptance, and battery telemetry cannot block healthy controls.
  Trunk and climate-OFF confirmation, legacy Exercise configuration, shared wake
  cancellation/restart and stale upload outcomes are covered by regressions.
- Fan-speed debounce remains one second and is now HA-owned. Normal wake/retry
  delays stay silent through 180 seconds plus 15 seconds of final confirmation.
  Requested/unconfirmed feedback remains gray; receipts do not imply playback or
  physical completion. Swipe-selected default persistence is retained.

## Validation and evidence

42 Swift core tests and unsigned iPhone/watch simulator builds passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/40128116674

The release repeated core tests and passed signed archive/export, deep signature,
production APNs entitlements, bundle/version checks, upload, Apple processing and
existing internal TestFlight access:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/40128954393

HA passed 242 regression tests, compilation/package/PHP checks and real Home
Assistant durable-storage/reload checks:
https://github.com/agawlbb/FanControlHA/actions/runs/40128342770
Live deployment and rollback: FanControlHA `DEPLOYMENT-0.9.0.md`.

IPA SHA256: `4d46d373bc43c2b725726c0ec648f1d7b661d8586b4bee80cc3b6f7a75dc4a03`.
Local signed IPA, Apple processing record, logs and signing-branch recovery:
`build/commands080/`. The temporary signing branch was retired with an exact-head
lease after preserving recovery evidence; the signing host's main was unchanged.

Remaining physical checks: cellular-only handoff, immediate swipe/wrist-down after
all watch actions, sleeping-car response, opposite intents/cancellation, HA restart
during delivery and local audio/headset behavior. Automated checks do not establish
physical delivery or watchOS background scheduling; ambiguous one-shots can remain
unconfirmed when the target supplies no deduplication or definitive acknowledgment.

---

# Vehicle reliability release — 0.7.0 (16), October 24, 2026

Uploaded and available to the existing **Internal** TestFlight group. Apple build
`4fa19c25-a9b5-4250-8654-03edac7b5f80` is `VALID`, not expired, and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testing group,
new tester, beta review submission or App Store release was created.

Signed application source: `e9e1e54da2288bc0736865d6093340d5b9756152`.
Later changes affect release verification/documentation only; application sources
and project settings are identical. Phone, watch and complication all report
0.7.0 (16). Paired hardware behavior has not been tested.

## Changes

- Explicit vehicle taps coordinate one wake/readiness attempt through HA 0.8.0.
  Operations preserve absolute intent, deduplicate submissions, avoid holding
  the shared HA lock during slow services, and never blindly replay one-shots.
- Delivery lasts up to 180 seconds plus 15 seconds of read-only confirmation.
  Normal wake/retry delays remain silent; missing evidence is not confirmed.
  Definitive rejection can report failure immediately.
- Exercise selection follows the person's morning arrival at either exercise
  location without waiting for car GPS. HA 0.8.0 is deployed and loaded;
  both existing pairings were preserved. Stop still selects a uniquely matching
  Driving panel once after the required outcomes are observed.

## Validation and evidence

38 Swift tests passed. iPhone/watch simulator builds, 13 synthetic captures and
unsigned archive passed; captures were visually reviewed. Signed archive/export,
deep signature, APNs entitlements, bundle versions and upload checks passed.
223 HA regression scenarios, Python compilation, package generation and real HA
runtime checks passed. Installed HA 2026.10.3 loaded the deployed integration.

- Simulator/core validation: https://github.com/agawlbb/FanControlWatch/actions/runs/40097060261
- Signed archive/upload: https://github.com/agawlbb/coffey-table-recipes/actions/runs/40097426044
- Final processing/internal access: https://github.com/agawlbb/coffey-table-recipes/actions/runs/40098120807
- HA final-source CI: https://github.com/agawlbb/FanControlHA/actions/runs/40097430298

The signing run's post-upload metadata verifier failed; the corrected standalone
verification above confirmed the same uploaded binary without rebuilding/reuploading.
The verifier has an isolated mocked Apple-response test. Private credentials stayed
in the existing runner and were removed at job cleanup.

IPA SHA256: `169353e4df9b7b7aa6613ace37d673936a66ffc0639173279eb81020c14b3e46`.
Local signed package, simulator captures and processing JSON: `build/vehicle070/`.
HA deployment and rollback details: the integration repository's `DEPLOYMENT-0.8.0.md`.

Remaining physical checks: asleep-car first tap, immediate gray feedback, delayed
confirmation, opposite intent/cancellation, offline phone, screen-off Stop,
actual morning arrival and notification suppression during normal delays.
Automated tests do not prove physical vehicle outcomes or paired-watch behavior.

---

# iPhone companion and Apple Watch — 0.6.0 (15)

Source: `3adaed3e3ad538ddd9fd097920cbab2ac6afdc65`.
Tested HA 0.7.0 source: `c40f5b9eae7f30bb32862c8fa9f66ef3431f2d23`.

## Behavior

- Minimal iPhone list: reorder approved tiles, import/reorder/remove audio, Sync.
  A separate gear button opens Settings independently of list reorder mode.
  Settings contains headset preference, connection status, refresh/relink/unlink
  and a separate diagnostics view. No explanatory notes in ordinary controls.
- Tile ordering is fixed, saved per watch through revision-checked HA preferences.
  Opening watch selection still comes from HA; swiping never changes HA selection.
- The phone owns routine APNs/background refresh and visible-phone refresh.
  Watch background tasks do no network refresh. The watch renders its saved panel
  immediately, asks the phone once on visible entry, and accepts passive snapshots.
- Direct watch commands, bounded validation/confirmation and settled visible
  vehicle entry remain independent of the phone. Cached states stay gray and
  tappable; requested intents never enter the observed cache. New phone snapshots
  cannot overwrite command feedback or that foreground session's intent target.
- Phone snapshots contain no credential. Watch/phone use independent Keychain
  keys; HA refuses commands from the companion. Watch revocation revokes both;
  phone self-unlink revokes only the companion key.
- Exercise imports MP3/M4A/AAC files (25 tracks, 30 MB each, 200 MB total), queues
  WatchConnectivity file transfers, checks size/SHA256 and atomically replaces
  the playlist only after all tracks arrive. Empty playlists and reordered lists
  work independently from snapshot sequence. A playing library remains available
  until the next playback session; an older receipt cannot label an edited draft
  as installed. Failed/interrupted transfers keep the previous playable library.
- Settings is no longer a swipe page. Hold a watch page for setup/recovery.
- Diagnostics separate HA attempt/APNs outcome, phone receipt/save, watch save,
  and the watch's first displayed panel. Missing evidence remains unknown.

## Validation

HA checks passed: 209 tests, Python compilation, package generation, PHP syntax,
real Home Assistant 2026.10.2 runtime, uv 0.13.4/Pillow 13.0.0 security overrides.
https://github.com/agawlbb/FanControlHA/actions/runs/39645595614

Local synthetic relay migration check passed: legacy SQLite registrations retain
watch destination, phone registration persists, arbitrary topics/destinations
are rejected. No APNs requests were sent by this check.

Apple final-source validation and signed package verification:
https://github.com/agawlbb/FanControlWatch/actions/runs/39652643037
https://github.com/agawlbb/coffey-table-recipes/actions/runs/39652653308

Apple checks passed: 37 Swift tests, iPhone and watch simulator builds/captures,
unsigned archive, signed archive/export, deep signature verification and production
APNs entitlement checks for both phone and watch. Bundle metadata confirms 0.6.0
(15) for phone/watch/complication, a launchable full-screen iPhone app and independent
watch operation. Main, first-launch and Settings captures were visually reviewed.
These are synthetic simulator rendering checks, not paired-device interaction tests.

- Signed IPA: `build/companion060/final/signed/FanControl.ipa`
- IPA SHA256: `fd2f34fa8ad1c314815d7b217ef48ab07864561bff26408a329f9b8a5df75257`
- CI HA package: `../ha-integration/dist/companion070/fan_control-0.7.0.zip`
- HA ZIP SHA256: `bb00f888d9e37614f0fa9187f0c4a9bcf891d2298e9ccdd1e0e5d2e615823e95`
- Captures: `build/companion060/final/screens/`

Only documentation changes follow the tested source commit. The existing HA CI
workflow was restored to its previous disabled state after successful validation.

## Deployment and physical checks

Install HA 0.7.0 and deploy its updated `relay/public/index.php` before companion
linking. Preserve the existing private relay configuration/key/database; the
public entry migrates legacy registration rows and uses the fixed phone APNs
topic `dev.fancontrol.watch`. The relay APNs key must authorize the phone topic and selected environment.
A team-scoped key can serve both apps; verify any topic-specific restrictions.
The phone receives no Apple private key or HA admin token.

Install the iPhone/watch package, open both apps and use Link watch if needed.
Existing watch pairing is retained.

### October 21 deployment and TestFlight upload

HA 0.7.0 and the pinned relay entry were deployed, backed up and verified.
Both existing HA watch identities and pairing secrets were preserved. The existing
production APNs key now authorizes both phone and watch topics, saved with the
user's explicit approval. HA recorded a post-deployment hint as accepted by APNs
(HTTP 202); device receipt remains unknown. See the integration repository's
`DEPLOYMENT-0.7.0.md` for deployment evidence and rollback locations.

The existing signing runner rebuilt the unchanged tested source commit, passed
all 37 Swift tests and signature/APNs entitlement checks, and uploaded 0.6.0 (15):
https://github.com/agawlbb/coffey-table-recipes/actions/runs/39655941241

Apple reported upload success at 18:58:13 UTC and processing `VALID` at
19:00:37 UTC on October 21. The build is not expired and declares no non-exempt
encryption. It was assigned to the existing Internal testing group; no new
testers, external review submission or App Store release was created.
App Store Connect build ID: `c359b4c2-e92b-4827-8108-b2d923e83674`.

The earlier IPA hash above describes the pre-upload signed verification package.
This upload was freshly signed from the same pinned source; it is a separate
signing output. Local upload logs and browser evidence are under
`build/companion060/` and are excluded from Git.

Paired hardware must still verify locked-phone APNs/background execution,
WatchConnectivity latency, first displayed panel, disconnected-phone commands,
request/confirmation colors, vehicle wake timing and offline headset playback.
Simulator captures are synthetic rendering checks; automated tests do not prove
physical delivery, playback or vehicle behavior. iOS background work remains
opportunistic, including when Background App Refresh is disabled or an app is
force-quit. Wear OS development/build/test/lint remains paused and untouched.
