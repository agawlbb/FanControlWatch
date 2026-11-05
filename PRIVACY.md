# Privacy

Fan Control sends requests to your configured Home Assistant addresses. It has no advertising, tracking SDK or developer analytics service.

The watch stores an independent revocable command credential in device-only Keychain storage accessible after first unlock. The phone receives a separate revocable companion credential through Apple's paired WatchConnectivity channel. It permits observations, approved preferences, push registration and diagnostics; HA rejects physical commands from it. The watch command key is never copied to the phone. HA watch revocation revokes both keys. Unlink phone revokes only the companion key.

The phone fetches snapshots using APNs, opportunistic background refresh and foreground refresh. It stores approved configuration, observations, tile order and diagnostics locally, and sends credential-free snapshots to the watch. The watch keeps its own key. Background work never wakes vehicles. Watch commands and their validation/confirmation reads go directly to HA.

Optional push uses Apple's APNs and https://coffeybean.com/FanControl/. HA sends its installation identifier, a paired-watch identifier, destination (phone or legacy watch), APNs device token and environment to the relay. Refresh payloads contain correlation hints. Automation alerts additionally send their title and full message through the relay and APNs. Ordinary refreshes do not send HA account credentials, entity IDs, observations or audio to the relay. Registration removal is best effort when the relay is unavailable. The relay cannot issue HA or vehicle commands.

Automation message text is retained in private per-watch HA storage and the iPhone's local messages/snapshot storage, and travels through the paired snapshot channel. Tapping an alert opens its full text in the iPhone app. The arrival automation clears all in-app messages through the next successful snapshot; Notification Center is unchanged. Unlinking the phone clears its messages. Alert text is not added to diagnostics.

Diagnostics retain up to 120 local events and HA attempts per watch, with correlation IDs, timestamps, panel identifiers and revisions. Review private entity names before sharing. Phone receipt, phone save and watch acknowledgment are separate evidence. APNs acceptance does not prove delivery. The relay retains up to 1000 attempts per installation. Device diagnostics are not sent to the developer.

Imported audio stays in private phone/watch storage and transfers through WatchConnectivity. It is not uploaded to the developer, relay or HA. Legacy explicit HA music download remains available in watch recovery. Headset names and the remembered watch audio-route identifier stay on the devices/paired HA. Removing a phone track takes effect on watch after Sync; ongoing playback can finish its current library. Unlink phone keeps the user's imported library. Forget connection on watch removes watch credentials, music and diagnostics.

Apple may provide TestFlight crash reports, beta feedback and diagnostics under its policies. Do not include private credentials or entity details in public issues. Use private GitHub security reporting when available.
