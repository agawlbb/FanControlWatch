# Immediate controls and push evidence — 0.5.2 (14)

Source: `62a428abd2dac63af4d6116bcc219f8afc4d47f3`.

[Signed build](https://github.com/agawlbb/coffey-table-recipes/actions/runs/39515685683) passed: 36 Swift tests, device archive, distribution export, signature/bundle/profile verification and production APNs entitlement/environment checks. The existing approved signing runner built source at that exact commit, using workflow commit `c45bb9581c8caf647fd284b454cfd9e0ab2edd00`. Upload was disabled; build 14 has not been submitted to TestFlight. The signed artifact is retained by GitHub for seven days and copied locally under `build/review052-build14/final-signed/` (ignored).

[Simulator/archive validation](https://github.com/agawlbb/FanControlWatch/actions/runs/39515664523) passed for the same final source: all 36 Swift tests, simulator compilation, screenshot generation and unsigned device archive. This confirms buildability and simulator capture, not physical-watch tap or car behavior.

Final signed IPA SHA256: `2b77b89d23640c900d66eb18a56399831062a3ee5f6a915641afc66a59846604`. Downloaded artifact digests were checked against GitHub metadata; both app bundles report version 0.5.2 and build 14.

[HA 0.6.3 checks](https://github.com/agawlbb/FanControlHA/actions/runs/39514438444) passed on `4321fd2e0b7bebc9255f2bc7a828d0cd7a5ca128`: 205 tests, Python compilation, PHP syntax, installable integration ZIP, installed-version/image checks and real HA 2026.10.2 load/options/actions/unload with uv 0.13.4 and Pillow 13.0.0. The HA workflow's prior disabled state was restored after validation.

The first Apple verification caught one superseded opening-cover expectation and a nondeterministic fixture timestamp; both were corrected before the successful run. A signing attempt in the Watch repository stopped at missing secrets; no credentials were copied there. Live HA/relay deployment and TestFlight upload were not performed.

Implementation:

- Gray power/climate/garage/trunk controls accept taps without an initial observation. Missing state presents gray OFF or CLOSED; moving covers present gray OPEN/CLOSED according to their direction. Taps choose the opposite absolute intent; same-toggle replacement invalidates older callbacks. Unrelated pending commands still block conflicting controls.
- Run script/scene accepts a request without a fresh state and immediately displays gray REQUESTED. Capability and target checks still occur before dispatch; one-shot actions are not replayed after an ambiguous send. Dispatch acceptance never confirms script completion.
- Fan speed drafts accept cached speed before freshness and use gray speed 1 when there is no observation. Bounds remain enforced. The one-second quiet window and serialization behind pending ON remain.
- Existing unlocked-only connection records migrate on foreground entry to after-first-unlock device-only Keychain protection, allowing locked-watch passive refresh after the first unlock. Before the first unlock, connection access can still fail.
- Entry reloads saved HA selection synchronously before showing controls. Inactive views do not show the old control page. Successful background save therefore needs no foreground network request to choose the panel. A missed/deferred push or failed refresh still requires foreground refresh; silent notification delivery is not guaranteed.
- Diagnostic revision changes do not invalidate an otherwise unchanged command target. Persisted snapshot comparison still includes revision so stale background work cannot overwrite a newer saved selection, including an A → B → A selection sequence.
- Settings → Push diagnostics shows persistent local evidence and can report pending events. HA 0.6.3 Download diagnostics reconciles them against send attempts by update ID. Receipt, configuration fetched, selection saved and opened are separate events. Opened captures the app's local selection before foreground refresh, not an independent measurement of watchOS's launch snapshot.

The paired HA 0.6.3 and updated relay must be installed for end-to-end correlation. No relay secret or signing key enters the watch. Background diagnostic reporting uses the passive reader's network policy and sends no controls or wake. Wear OS is unchanged.

Hardware checks remain: gray first taps, rapid reversal and stale replies, speed drafts while ON is pending, locked/wrist-down push receipt, delayed receipt upload, offline recovery, first visible panel after a two-minute wait and absence of background vehicle wake. Automated checks cannot establish physical-watch rendering, APNs delivery or car behavior.
