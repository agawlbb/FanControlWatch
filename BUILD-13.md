# Passive push refresh — 0.5.1 (13)

Source: `9cbc0d0eed2ff3d57cce6d4ccae938e0c44c1948`.
[Signed build and upload](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39503517223)
passed on October 20, 2026. All 31 Swift tests, device archive, export, strict
signature/team/bundle checks and the exported production APNs entitlement check
passed. The exported watch's configured APNs environment is production. Apple
accepted the upload at 5:54 PM EDT. The
[TestFlight check](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39503517389)
confirmed VALID and IN_BETA_TESTING in the existing Internal group at 5:58 PM
EDT. The App Store Connect group Builds page independently shows 0.5.1 (13)
Testing, with the existing one tester retained. Test notes are saved.
Build ID: `cccc7395-9161-4f37-a199-f52119b371a3`.
Local UI proof: `build/review051-build13/testflight-ready.png` (ignored).

The first attempt stopped before compilation/upload because the Apple bundle-ID
query returned related identifiers. The corrected signing preflight selects only
the exact watch bundle ID before enabling its Push Notifications capability.
No existing build was replaced and the failed attempt did not consume build 13.

- HA 0.6.2 sends hints for this watch's selected panel and relevant observations.
  Inactive cars and unrelated attributes do not generate hints.
- Push and periodic background refresh read HA configuration and selected-panel
  observations without entering the foreground vehicle-wake path.
- Swipe entry waits 1.5 seconds, measured from the swipe with a monotonic clock;
  leaving cancels it. Primary foreground entry resolves HA selection and wakes
  without that artificial delay. No cooldown was added.
- Ordinary configuration refresh does not initiate vehicle wake. Cached state,
  command evidence and APNs acceptance remain separate.

The relay's production signing key is held in private host storage; relay credentials
and APNs keys are absent from Git and build artifacts. Live HA is configured and
the relay's authentication/replay checks passed without sending a push or vehicle
command. Previous simulator compilation/capture generation and unsigned archive
passed for the same watch app code; the only subsequent code change corrected
the signing preflight.

After installing: verify actual APNs token registration and wrist-down delivery,
rapid swipe-through without wake, a settled swipe waking once after 1.5 seconds,
primary entry waking the correct selected car, and offline/late-callback recovery.
Automated checks do not establish physical-watch timing, rendering or car behavior.
Wear OS code/builds/tests/lint were not touched under its development pause.
