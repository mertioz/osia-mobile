# WOR-357 — one Thinking section per assistant reply

## Root cause and correction

History reconstruction used the same request/turn/run identity for a user row and its assistant reply. `_retainThinkingTrace(null, key: ...)` could restore an already retained assistant trace onto the user row. The renderer displayed any row's trace without a role check, producing duplicate commentary and a Thinking section above a user message. Reconstruction now restores traces only for assistant messages; rendering independently enforces assistant ownership.

The cancellation-terminal path previously assigned a retained snapshot directly to the trailing slot even when the assistant entry already existed. It now uses the same exact-identity attachment function as ordinary trace events. A live assistant row owns its trace; the trailing status slot is only used before an assistant row exists. Even an empty streaming row suppresses a second pre-stream placeholder.

The exact-one requirement also covers completed/legacy assistant responses with no recorded public commentary or trace. Both Mobile and Desktop now retain one empty disclosure above such replies. It contains no invented reasoning, event, execution identity or completion claim. This supersedes older tests which hid the entire empty disclosure; assertions against fabricated summary text remain unchanged.

## Placement and lifecycle

The real Mobile ChatScreen composes each assistant row as Thinking, then ChatBubble. User/system rows receive no disclosure. An unrecorded trace uses the existing empty ThinkingDisclosure, not a synthetic execution snapshot. Its UI memory is scoped to the canonical request, or the conversation/message slot for legacy history. On receipt of a real trace, the same per-request disclosure memory preserves manual collapse. Completion changes activity/state in that assistant slot and collapses once; reopening exposes retained public provider text. Separate turns keep separate history.

Desktop's existing role guard and keyed trace map already prevented the user-role duplication in ordinary history. The Qt follow-up adds an empty disclosure for legacy assistant responses without a trace, retains empty terminal controls, and moves an existing pending trace immediately above its assistant row instead of adding another. No duplicate history is hidden/deleted.

Six animated orbs, new-turn automatic expansion, live public commentary, manual collapse/reopen, exact cancellation identity and the WOR-354 NoSplash/focus treatment remain. Canonical PC storage, provider events, parser/ActionTruth, protocol and Mobile projection authority are unchanged. No hidden reasoning is exposed and no semantic similarity filter removes repeated legitimate provider events.

## Verification and limits

- Real ChatScreen: consecutive user/assistant history, shared user/reply identity, longer reconnect snapshot, preserved commentary, an unrecorded legacy reply, third-turn streaming, terminal collapse/reopen, exact widget count and vertical ordering above replies.
- Real offscreen Qt: consecutive turns, streamed answer, completion, cancellation, replay and restored history; original widget identity retained, commentary once, and an unrecorded legacy reply with one empty control.
- Existing trace revision/merge, per-turn disclosure, cancellation, accessibility, reduced-motion and touch-highlight tests retained. An unrelated reduced-motion lazy AnimationController initialization found by real-screen teardown was corrected earlier in this mission.
- A cancellation timing test exceeded its 0.5-second wall-clock assertion once during concurrent native/Flutter tests (0.532 seconds); its unchanged eight-test cancellation suite passed on focused rerun. No runtime cancellation limit or test threshold was changed.

This is source/widget/Qt verification. No new Android/iOS package was built or installed. The Pixel still has the previously accepted 1.1.2+18, and fresh physical acceptance of these new composition changes remains pending. iOS physical acceptance remains pending as well.
