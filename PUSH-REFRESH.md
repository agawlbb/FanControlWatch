# Passive push refresh — 0.5.1 (13)

The watch registers its APNs device token with HA using its existing encrypted
pairing. No Apple signing key or hosted relay secret is sent to the watch.
Background notifications only call the passive refresh reader: fetch current HA
configuration and the selected panel's observations. They never navigate, dispatch
commands, confirm pending outcomes or invoke the foreground entry/wake path.
Foreground polling remains active while displayed; the periodic background
refresh remains as fallback. watchOS can defer or discard silent notifications.

Primary foreground entry refreshes HA selection before wake with no artificial
delay. Swipe entry requires 1.5 seconds continuously on that page, measured with
a monotonic clock from the swipe. The deadline survives configuration revalidation.
Leaving cancels the task and invalidates its generation. Each entry can attempt
one wake; no cooldown was added. A wake already sent cannot be recalled.
Configuration changes discovered by ordinary polling never initiate entry wake.

Enable Push Notifications for dev.fancontrol.watch.watchkitapp in Apple signing.
The development entitlement is converted to production by distribution export;
the signing script verifies the exported entitlement and payload environment.
Debug registers sandbox tokens; exported Release registers production tokens.
The complication remains a static active-panel launcher.

Physical checks still needed: fast pass-through swipes produce no wake; a settled
swipe sends one after 1.5 seconds; primary open resolves the correct car and wakes
without the swipe delay; leaving/settings/background/push produce no wake; check
late reads, changed configuration, wrist-down, locked watch and offline recovery.
Verify signed APNs registration and real background delivery after relay setup.
