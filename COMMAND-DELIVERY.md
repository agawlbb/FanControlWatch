# HA-owned command delivery (Apple 0.8.0 / HA 0.9.0)

Every HA control submits an absolute intent with a stable UUID and original issued
time. A keychain outbox records the captured connection, target and body before a
watchOS background URLSession upload is scheduled. Foreground submission and remote
fallback use the same operation ID with independently authenticated fresh envelopes.
No config/state read is required before handoff; HA validates the captured roles.

Leaving or wrist-down cancels UI observation only. HA saves acceptance before its
acknowledgment and before physical dispatch. HA then owns readiness, one bounded
wake, safe desired-state retries and observed confirmation for 180 seconds plus a
15-second read-only grace period. The operation store restores work after restart
without extending that deadline. Fan speed's one-second quiet window is server-owned
and superseded drafts cannot execute later. Reopening resumes the same operation
and its stored result. Unrelated HA selection or other panel edits do not redirect
or block delivery.

HA persists the at-most-once boundary before cover/horn/script/scene delivery.
After an ambiguous call or restart these actions are never replayed. This means an
ambiguous one-shot can remain unconfirmed: no distributed system can guarantee both
physical completion and no duplicate effects without support from the target.
Scripts/scenes/music and horn confirm dispatch acknowledgment, not physical completion.
Local audio/volume remain watch-owned. Explicit cancellation, revoked credentials,
removed/changed roles and expired requests still stop delivery.

Normal wake/retry delays produce no one-minute alerts. Final Exercise alerts come
from HA; the originating controls show pending, rejected, cancelled or unconfirmed
status in gray. Unknown/unavailable observations never confirm a command.

Validation requires core transport/evidence tests, HA regression and real-runtime
checks, and unsigned simulator compilation. Paired-watch cellular, immediate wrist-
down/navigation, force-quit/OS scheduling, sleeping car and physical target behavior
still require device checks. Apple controls background scheduling; a saved upload
cannot guarantee immediate execution, especially after user force-quit. No live
HA commands, deployment or TestFlight upload form part of these automated checks.
