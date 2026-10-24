# Apple Watch and iPhone development

## Repository ownership and offline work

The canonical repositories are `C:/Users/mailb/StudioProjects/FanControl/apple-watch`
(agawlbb/FanControlWatch) and `C:/Users/mailb/StudioProjects/FanControl/ha-integration`
(agawlbb/FanControlHA). Work only in the repository assigned to the task.
The connected laptop owner is the chat "FanControl owner" (01a15b0b-d82d-7dd2-b5ce-4e3f9bf236b8);
coordinate handoff before another chat writes. Verify current heads and local
changes before editing; preserve unexpected work. Labelled recovery copies remain
archives and must not become active checkouts.

When explicitly asked to work offline, use a named `codex/` branch in the same
repository. On laptop return, the owner reviews, merges, validates and synchronizes
that branch. Delete it only after its work is preserved. Complete work with commits
and pushes; verify clean local state and matching GitHub heads before reporting done.
Inspect push workflows first. Do not trigger releases, deployment, device installation
or distributable builds without authorization. Never change branch protections
without specific approval. Back up before deletion/history rewrite, exclude ignored
credentials/runtime/signing material, preserve release tags, and use exact-SHA
force-with-lease for authorized rewrites. Never purge recovery archives.

## Current behavior

The iPhone owns routine APNs/background refresh and visible-phone polling. The
watch renders persisted snapshots and asks the phone once on visible entry; do
not add watch background polling or a foreground refresh loop. Phone/background
reads never wake vehicles. Direct watch commands and their bounded validation
and confirmation remain independent of the phone.

A swiped tile persists as the local opening tile until another swipe or an HA selection/configuration revision. Saved phone preferences define a fixed swipe order;
swiping never changes HA selection. Settings is reached by holding a watch page,
not by swiping. Keep the phone UI minimal. Only Driving has an identification stripe.
Visible primary vehicle entry wakes after target validation without artificial
delay; swipe entry waits 1.5 seconds continuously visible. Leaving cancels entry
work. Explicit vehicle taps may start or join one bounded wake attempt. Prefetch/configuration/background reads and command retries never initiate additional wake requests. Apple commands allow 180 seconds plus 15 seconds of read-only confirmation; expected wake/retry delays remain silent.

## Command evidence

Immediately project the requested absolute outcome in gray on the originating
control. Never store projection as observed state. Gray toggles remain tappable:
an opposite absolute intent supersedes earlier UI work. Preserve the one-second
fan-speed quiet window. Stale responses cannot recolor another request or target.
Matching available HA observations can confirm toggles, fan speed and covers in
teal. Unknown, unavailable, mismatched, timed-out and ambiguous results stay gray.
Garage/trunk initial CLOSED is only a gray assumption; its first tap is absolute
OPEN. Dispatch cover/script/scene/music requests at most once per tap.

Leave for Work, Horn, Start/Stop Exercise and Podcast show gray Activated after
a tap and teal Activated only after authenticated HA acceptance; that is receipt,
not physical completion or playback proof. Retain receipts for the active session
and reset on leaving/configuration change. Generic script/scene controls preserve
their existing receipt semantics. Pending conflicting actions remain disabled.
Stop continuation must survive accepted dispatch; Driving selection requires HA
operation completion. Local Exercise Stop confirms unlock and climate on; the
63 F temperature request is best effort. Preserve existing legacy-client semantics.

Keep imported audio private and offline on the watch. Verify a whole replacement
before installing it; preserve the playing library until the next session. Phone
snapshots contain no command credential and cannot confirm a watch command.

## Validation

Preserve regression tests and build/release configuration. For command changes,
cover immediate intent, delayed/mismatched/unavailable evidence, confirmation,
failure/cancellation and stale callbacks across exposed surfaces. Run appropriate
core tests; simulator/signing builds require their own authorization. Report exact
source and remaining paired-device checks. Automated checks do not establish real
watch rendering, APNs delivery, playback or vehicle behavior.
