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
