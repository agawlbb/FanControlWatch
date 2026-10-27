# Apple Watch and iPhone development

## Repository ownership and offline work

The canonical repositories are `C:/Users/mailb/StudioProjects/FanControl/apple-watch`
(agawlbb/FanControlWatch) and `C:/Users/mailb/StudioProjects/FanControl/ha-integration`
(agawlbb/FanControlHA). Work only in the repository assigned to the task.
The primary repository owner is the cloud chat "FanControl cloud owner".
Ownership was transferred to the cloud by the user on October 27, 2026 and remains
with the cloud when the laptop reconnects. Coordinate handoff with the cloud owner
before another chat writes. Verify current heads and local
changes before editing; preserve unexpected work. Labelled recovery copies remain
archives and must not become active checkouts.

When explicitly asked to work offline, use a named `codex/` branch in the same
repository. The cloud owner reviews, merges, validates and synchronizes
that branch; laptop-owner review or merging is not required. Delete it only after its work is preserved. Complete work with commits
and pushes; verify clean local state and matching GitHub heads before reporting done.
Inspect push workflows first. Do not trigger releases, deployment, device installation
or distributable builds without authorization. Never change branch protections
without specific approval. Back up before deletion/history rewrite, exclude ignored
credentials/runtime/signing material, preserve release tags, and use exact-SHA
force-with-lease for authorized rewrites. Never purge recovery archives.

## Required design for future controls

Apply these rules to every new or changed HA-controlled action on every watch
surface, including panels, shortcuts and complications. First-tap completion is
the design goal for a valid, authorized target: recover ordinary wake, transport
and provider delays without requiring another tap. Do not add a separate delivery
path for a new control. Use the shared command outbox and HA operation API described
in [COMMAND-DELIVERY.md](COMMAND-DELIVERY.md), with the corresponding server contract
in the HA repository's `COMMAND-OPERATIONS.md`.

- Capture one absolute intent, approved target, unique operation ID and original
  deadline at the tap. Save it securely and schedule background submission before
  monitoring. Retries, endpoint fallback and reopening must use that same intent
  and ID; never recompute a toggle from a later read. No preflight read may gate
  submission. HA remains authoritative for authorization and role validation.
- The watch owns delivery until HA durably acknowledges acceptance; HA then owns
  readiness, bounded wake, execution, retry and confirmation. Screen navigation,
  wrist-down and UI task cancellation must not cancel handoff or accepted work.
  Reopening reconciles the saved operation. Only explicit cancellation, a newer
  conflicting intent, revocation/target invalidation or expiry may stop it.
- Keep queue acceptance, dispatch acknowledgment and confirmed outcome distinct.
  Project the requested outcome immediately in gray. For EVERY command control, teal requested ON/OFF, speed, cover state or Activated means authenticated HA ownership of this exact operation and target, not physical completion. Never put projected state
  in the observed cache. Scripts/scenes/horn/music receipts do not prove physical
  completion or playback. Stale callbacks must not change a newer request.
- Declare whether each new command is a retryable desired state or an at-most-once
  action. Persist one-shot dispatch boundaries on HA; never blindly replay an
  ambiguous action for better feedback. Keep conflicting controls disabled while
  preserving supported opposite-intent supersession and fan-speed adjustment.
- Keep expected wake/retry delays silent through the shared 180-second delivery
  and 15-second read-only grace policy. Treat transient network errors, rate limits
  and temporary server errors as retryable within that deadline. Final failures
  stay gray; never claim an unproven success.
- Local-only actions such as audio and volume remain watch-owned; their feedback
  and evidence must remain independent of HA or vehicle completion. Keep background
  command transfer separate from passive reads; do not add background polling or
  passive vehicle wakes. Clear saved command credentials when forgetting pairing.

Before delivering a new command, cover immediate feedback, early navigation and
wrist-down, lost acceptance responses, same-ID retry/fallback, delayed/unavailable
or mismatched evidence, terminal failure, explicit cancellation, supersession,
stale callbacks, target/revocation changes and restart recovery. Verify the HA
worker and any one-shot recovery behavior as well as the watch path. Add meaningful
regression coverage and record paired-device checks that automation cannot prove.
Do not promise guaranteed OS scheduling or exactly-once physical effects when the
target supplies no deduplication/definitive acknowledgment. Coordinate required HA
capabilities and version compatibility before introducing a dependent app action.

## Current behavior

The iPhone owns routine APNs/background refresh and visible-phone polling. The
watch renders persisted snapshots and asks the phone once on visible entry; do
not add routine watch background polling or an unbounded foreground refresh loop.
Every displayed nonvehicle control also performs one bounded authenticated HA state
read on entry, without requiring a phone or command tap. Available ON/OFF and speed
observations may turn teal; unknown/unavailable data and saved snapshots stay gray.
Keep this separate from command acknowledgment and vehicle report-age checks.
Vehicle changes must preserve this opening-screen behavior for fans, lights,
switches, booleans and nonvehicle panels. Cover opening without issuing a command
when validating refresh changes. Bounded visible-entry wake/readiness confirmation is required. Phone/background
reads never wake vehicles. Direct watch commands remain independent of the phone. Save every absolute intent
in the keychain outbox and schedule its background upload before monitoring.
HA owns durable execution after acceptance, across watch navigation/inactivity and
HA restart. Leaving cancels observation/entry work only, never accepted delivery.
Resume the same operation on return; unrelated selection/config changes must not
block a valid captured target. No command preflight reads or watch background polling.

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
fan-speed quiet window on HA; the watch hands off each revised draft immediately. Stale responses cannot recolor another request or target.
Authenticated HA ownership turns every requested command control teal immediately, including Climate. Execution/conflicting-control protection remains pending independently of color. Terminal failed/unconfirmed/cancelled results turn it gray. Observed state and its freshness are tracked separately; unknown observations are never confirmed.
Garage/trunk initial CLOSED is only a gray assumption; its first tap is absolute
OPEN. Dispatch cover/script/scene/music requests at most once per tap.

Command feedback uses color on the existing control, without separate status
messages such as Requested, Waiting for Home Assistant, Request accepted or Not
confirmed. Action buttons intentionally change to Activated after a tap; retain that behavior. Do not use REQUESTED as a generic replacement. State controls immediately show the requested ON/OFF, OPEN/CLOSED
or speed in gray; authenticated ownership promotes their color to teal before physical completion. Failures stay gray.
Setup, pairing and audio-route guidance are separate from command feedback.

Leave for Work, Horn, Start/Stop Exercise and Podcast show gray Activated after a tap. Teal Activated means an authenticated response matching this operation confirms HA has received the command and owns ensuring completion. Active operation statuses acknowledge that handoff before dispatch/completion. It does not prove physical completion or playback. Keep monitoring and conflict protection independent of the receipt color; terminal failures remain gray. Resetting session presentation on
leaving/configuration change must not delete saved operations or prevent
reconciliation on return. Generic script/scene controls preserve their existing
receipt semantics. Pending conflicting actions remain disabled.
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

## Entry, outcome notifications and timing

Vehicle panels perform one scoped, bounded wake/readiness refresh on visible settled
entry. Passive snapshots cannot cancel that coordinator or initiate an offscreen
wake. Cold/unconfirmed climate presentation assumes OFF in gray, making its first
tap an absolute ON intent; never toggle from stale cached ON. Once tapped, preserve
the captured absolute intent through leaving, retries and configuration refreshes.
Foreground and background authenticated receipts update the same visible control;
reopening reconciles the latest keychain receipt before another network read.

User-command terminal failures use HA-owned APNs to a dedicated watch destination;
phone snapshot registration cannot replace it. No failure alert for ordinary wake
or pending delays. A bounded local not-confirmed fallback covers missing HA
acknowledgment; cancel it when HA ownership is received. Entry-only wake failures
are diagnostic, not extra user-command alerts. Notification permission, relay
availability and OS delivery remain prerequisites; APNs acceptance is not receipt.
On recovery, reconcile pending/delivered local alerts against the current outbox,
pairing, target roles, acknowledgment and original issue time. Never replay an
overdue timer or notify from an orphaned/obsolete callback. Local alert relevance
is bounded to five minutes from the original tap; native timers still target
195 seconds plus 30 seconds of transport grace. Deduplicate local fallback and
terminal alerts, recheck relevance after asynchronous permission/notification work,
and remove obsolete legacy Exercise timers. Entry reads/wakes never create alerts.
Keep all timing diagnostics bounded and correlated by operation ID. Record tap,
submission, acknowledgment received/displayed and entry wake/state-display timing;
never log credentials, tokens, URL contents or full request bodies. Preserve these
rules and meaningful lifecycle/notification regression coverage for future controls.
