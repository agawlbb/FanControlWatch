# Immediate controls and push evidence — 0.5.2 (14)

Implementation:

- Gray power/climate/garage/trunk controls accept taps without an initial observation. Missing state presents gray OFF or CLOSED; moving covers present gray OPEN/CLOSED according to their direction. Taps choose the opposite absolute intent; same-toggle replacement invalidates older callbacks. Unrelated pending commands still block conflicting controls.
- Run script/scene accepts a request without a fresh state. Capability and target checks still occur before dispatch; one-shot actions are not replayed after an ambiguous send. Dispatch acceptance never confirms script completion.
- Fan speed drafts accept cached speed before freshness and use gray speed 1 when there is no observation. Bounds remain enforced. The one-second quiet window and serialization behind pending ON remain.
- Existing unlocked-only connection records migrate on foreground entry to after-first-unlock device-only Keychain protection, allowing locked-watch passive refresh after the first unlock. Before the first unlock, connection access can still fail.
- Entry reloads saved HA selection synchronously before showing controls. Inactive views do not show the old control page. Successful background save therefore needs no foreground network request to choose the panel. A missed/deferred push or failed refresh still requires foreground refresh; silent notification delivery is not guaranteed.
- Settings → Push diagnostics shows persistent local evidence and can report pending events. HA 0.6.3 Download diagnostics reconciles them against send attempts by update ID. Receipt, configuration fetched, selection saved and opened are separate events. Opened captures the app's local selection before foreground refresh, not an independent measurement of watchOS's launch snapshot.

The paired HA 0.6.3 and updated relay must be installed for end-to-end correlation. No relay secret or signing key enters the watch. Background diagnostic reporting uses the passive reader's network policy and sends no controls or wake. Wear OS is unchanged.

Hardware checks remain: gray first taps, rapid reversal and stale replies, speed drafts while ON is pending, locked/wrist-down push receipt, delayed receipt upload, offline recovery, first visible panel after a two-minute wait and absence of background vehicle wake. Automated checks cannot establish physical-watch rendering, APNs delivery or car behavior.
