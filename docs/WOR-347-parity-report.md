# WOR-347 — PC / Android / iOS parity reconciliation

Date: 20 October 2026 (Europe/Paris). Implementation in the two PRIMARY
repositories only. No worktree, installer, phone build, store submission or upload.

This report distinguishes source and deterministic evidence from installed-device
acceptance. WOR-347 remains In Progress while the critical physical provenance,
rendering and reconnect scenarios have not been observed. WOR-348 is the next gate.

## Baselines, reconciliation and preserved work

| Repository | Initial primary main | Initial verified GitHub main | Validated product/test delivery |
| --- | --- | --- | --- |
| Desktop | `261d4a149499dcdf9f6ea3a5df5e87d8e2406526` | same | `8e187ef17dfc74c13f617f9f5e4abd2a51c5f6bc` |
| Mobile | `8c9a974386afbae3c8eaeac4dfed4139a74a54a3` | `b47da71df0f02ee43ef70f312267ff2ffaaba386` | `bb3acd190ec585043cc43ecc4fa729356e20ad7a` |

Both indexes were initially empty. Fetch and `git ls-remote origin refs/heads/main`
verified the remote directly. Mobile was three commits behind. Every upstream
changed file was compared with the working copy: nine tracked code/test edits and
three untracked tests already matched upstream after CRLF normalization. The README
was independent local work. Only the two reviewed remote differences were applied:
the legal-asset LF attribute and an explicitly non-secret test token. Index and
branch metadata were then advanced without replacing the equivalent working files.

Recoverable original bytes and SHA-256 manifest are in the local temporary folder
`osia-wor347-mobile-originals-2pplex1e`. That backup is not a runtime dependency.
The README remains modified and unstaged. Desktop's pre-existing deletion of
`.claude/settings.local.json` and all pre-existing untracked evidence, tools,
benchmarks and experimental source remain outside these commits. No stash, reset,
clean, force-add, force-push or broad restore was used.

Each correction below was tested, reviewed, scanned, explicitly staged, committed
and pushed. Primary HEAD, origin/main and live GitHub main were compared after
each push and rechecked after the operator's PC restart. Documentation commits
follow the product SHAs above; the final delivery SHA is recorded in Linear.

## Demonstrated discrepancies and corrections

| Initial classification | Finding | Correction and affected callers |
| --- | --- | --- |
| IMPLEMENTED_BUT_STALE_RUNTIME | Primary Mobile Git metadata lagged the code already present locally. Existing APK artifacts predate V5. Installed build remains unknown. | Safe primary reconciliation; preserve independent local work; separate source, artifact and device identities. |
| PARITY_CONFIRMED | V5 was already implemented in `ExecutionTraceBlock` and `ThinkingDisclosure`; rewriting it would not establish the installed cause. | Add real `ChatScreen` tests exercising accepted/trace/chunk/terminal events, navigation and disclosure transitions. |
| WIRE_CONTRACT_MISMATCH | PC sends `quotaWindows[].remainingPercent`; Mobile read only the older `usagePercent`. | `ChatGptQuotaWindow`, `ChatGptAccountState.fromJson/withoutEphemeralLogin`, account card, six-language labels. Invalid entries discarded; zero remaining is preserved. |
| MOBILE_BEHAVIOR_DIFFERENT | Mobile normalized runtime-defined effort IDs such as `ultra` to `auto`. | `OsiaReasoningConfig` preserves syntactically valid IDs. Canonical model metadata/server still decide support. No new planner or model routing. |
| MOBILE_MISSING / WIRE_CONTRACT_MISMATCH | PC Claude API editor supports a workspace; Mobile lacked the field and server `set_setting` rejected it. | Forward snapshot through provider navigation, live editor, workspace-only save and workspace-before-key ordering; PC accepts and validates the non-secret setting. |
| MOBILE_BEHAVIOR_DIFFERENT | Completed Mobile answers supported only a small Markdown subset; user text was incorrectly interpreted as Markdown. | Completed assistant answers render GFM with pinned `flutter_markdown_plus` 1.0.12; user text stays literal; live partial delimiters remain available. Local-device image paths are not loaded from model prose; HTTP(S) links retain scheme checks. |
| MOBILE_BEHAVIOR_DIFFERENT | An open provider list retained old credential-presence badges, workspace and fallback counts after PC config changes. | `_ProviderListScreen` subscribes to canonical config snapshots; editor opens with current metadata. |
| MOBILE_BEHAVIOR_DIFFERENT | Changing Mobile language left subsequent text/audio/attachment requests with the old client locale. | `ChatScreen` listens to `LanguageController`, transfers the listener on controller replacement and removes it at dispose. Same socket and turn ownership retained. |
| MOBILE_BEHAVIOR_DIFFERENT | LAN certificate ACL probes failed when Windows PowerShell inherited Core-only `PSModulePath`; `Get-Acl` could not load its Security module. | `lan_gateway._windows_acl_environment` isolates the two short ACL probes. Parent environment, required private-key ACL and TLS pin checks remain intact. |

No provider lifecycle/parser, browser launch/profile/single-window logic, canonical
tool dispatcher, OAuth SDK compatibility layer or release version was rewritten.
The only new PC control surface is the existing non-secret workspace setting on
the existing `set_setting` route; no new WebSocket message family was needed.

## Thinking V5: source truth and timing

Desktop truth: `osia/gui/main_popup.py::_ChatThinkingTrace`, `_ChatPage.begin_turn`,
`set_thinking_trace`, `osia/gui/thinking_orbs.py::ThinkingOrbs`.
Mobile: `lib/widgets/execution_trace_block.dart::ExecutionTraceBlock`,
`ThinkingDisclosure`, `ExecutionTraceDisclosureState`, and
`lib/widgets/thinking_orbs.dart::ThinkingOrbs/thinkingOrbPoints`.
Chat retains disclosure and public snapshots by exact `ExecutionTraceKey` in
`_thinkingDisclosures/_thinkingSnapshots`; the service owns transient correlated
transport projection, not a second conversation database.

The six-orb geometry is periodic, including the seam. Animation is suppressed for
inactive/offscreen, background, disabled ticker and reduced-motion cases and
disposed with its widget. Acceptance opens the empty disclosure before commentary.
No empty-state prose is invented. Public commentary is kept through partial
snapshots, revisions, bubble remounts and history. A manual close is retained for
that exact turn; first final chunks do not close it. Canonical terminal settlement
collapses once, stops orbs and permits manual reopening. Safe display text does not
change stored provider wording. Tool facts are not fabricated into Thinking.

| Scenario | Deterministic evidence | Physical Android / iOS |
| --- | --- | --- |
| Accepted turn before any commentary; no commentary available | V4/V5 widget tests and new ChatScreen semantics assertion | NOT_TESTED / NOT_TESTED |
| Delayed/multiple/revised public commentary | Thinking accumulator and nine provider-identity projection fixtures | NOT_TESTED / NOT_TESTED |
| Manual close before first commentary and while streaming; reopen | Waiting → trace → answer-bubble transition in real ChatScreen | NOT_TESTED / NOT_TESTED |
| Natural completion, cancellation, provider error | Three new canonical ChatScreen terminal scenarios | NOT_TESTED / NOT_TESTED |
| New turn / supersession / different conversation / stale IDs | Exact-key tests, next-turn disclosure reset, durable lifecycle suites | NOT_TESTED / NOT_TESTED |
| Settings navigation, widget rebuild and scrolling | Chat navigation/remount tests and orb visibility tests | NOT_TESTED / NOT_TESTED |
| Background/foreground and reduced motion | Widget lifecycle/ticker pumping and connection lifecycle unit tests | NOT_TESTED / NOT_TESTED |
| Disconnect/reconnect and replay ordering | Durable event cursor/ACK, suffix replay and current-turn correlation tests | NOT_TESTED / NOT_TESTED |
| Completed historical turn and duplicate terminal after manual reopen | Retained public history and disclosure tests | NOT_TESTED / NOT_TESTED |

Canonical PC emission is independently covered by
`test_wor340_thinking.py::test_desktop_mobile_bridge_is_public_correlated_and_ordered`
and the FIFO forwarder test: accepted → public traces → terminal status, with exact
run/provider/model binding, rejection of stale/unsafe input, and public text retained.
Flutter screen evidence is in `test/chat_settings_navigation_test.dart` and the
existing WOR-340/WOR-311 suites. These are HARNESS_VERIFIED and WIDGET_VERIFIED,
not observations of the operator's installed application.

Cause assessment: A (stale primary metadata) confirmed but local V5 files were
already present; B (old local APK artifacts) confirmed, installed identity unknown;
C–F are covered in source/fixtures, with no demonstrated remaining V5 widget/wire
defect. The installed visual regression cannot honestly be attributed to a precise
binary until WOR-348 records its identity and runs the same scenarios on phones.

## Functional matrix — current source and deterministic contracts

In this table **P** means PARITY_CONFIRMED at SOURCE_VERIFIED and, where the listed
suite exercises it, HARNESS_VERIFIED/WIDGET_VERIFIED levels. Android and iOS use
the same Dart Chat/service code. A **P** in their source columns is not
DEVICE_VERIFIED. **D** means DEVICE_SPECIFIC; **U** means TECHNICALLY_UNSUPPORTED.
All physical Android/iOS rows remain NOT_TESTED in this execution.

| Capability / operations | Canonical PC owner and Mobile projection / controls | PC / Android source / iOS source | Evidence or qualification |
| --- | --- | --- | --- |
| Conversation create/list/load | `conversations.py`; server `new_conversation`, `conversation_history`; `WebSocketService.sendNewConversation/sendLoadConversation` | P / P / P | canonical Chat and history tests |
| Send, streamed deltas and exact final replacement | server `_run_agent_and_respond`; service `_appendConvDelta/_finishConvStream`; `ChatScreen._onConvStream` | P / P / P | WOR-177, Chat navigation/typewriter tests |
| Rename/delete and rollback/ack reconciliation | PC canonical receipts; `sendDeleteConversation`, `_resolveConversationDeletion` | P / P / P | Desktop-origin deletion, failure and stale-list tests |
| Project create/rename/move/collapse/delete and new project chat | PC conversation folders; Mobile folder controls/operation IDs | P / P / P | WOR-243 and Chat navigation tests |
| History, conversation switching and persistence | PC JSON store and correlated snapshots; transient Mobile projection | P / P / P | WOR-216 ledger, WOR-265 recovery, canonical history suites |
| Search/navigation | Existing sidebar/history/project navigation and canonical tool search; no separate native chat-search engine found in either client | P / P / P | source inspection; no new search feature invented |
| Markdown, tables, lists, code, Unicode, links and text copy | Qt GFM without HTML; Mobile completed GFM + SelectionArea; streaming cursor retained | P / P / P | WOR-347 Markdown, 320 px long-code/table test, canonical streaming tests |
| Stop/cancel, errors, recovery and long turns | PC exact-turn authority; `cancel_active_work`; no overall Mobile objective ceiling | P / P / P | WOR-269, send/stop, watchdog/recovery suites |
| Provider/model catalog and exact selected identity | `mobile_model_catalogue.build_model_inventory/build_catalogue`; Mobile provider+model keys | P / P / P | catalogue, WOR-298 and model selector tests |
| DeepSeek catalog | PC canonical `deepseek-flash`; no restored retired selectable ID | P / P / P | DeepSeek regressions; old synthetic fixture corrected |
| Reasoning options and selected state | PC runtime metadata and pair validation; syntax-preserving Mobile config | P / P / P | reasoning/catalogue tests including runtime-defined IDs |
| ChatGPT Account login/cancel/logout/status | PC managed auth; sanitized `ChatGptAccountState` | P / P / P | account lifecycle/freshness/logout and settings widgets; live login NOT_TESTED |
| Quotas and unavailable/unsupported model handling | PC safe remaining windows; Mobile read-only status and error state | P / P / P | quotas 0–100, malformed entries, disconnect and catalog fixtures |
| Claude API native Messages/compatibility | PC inference/auth transport; same selected provider on Mobile | P / P / P | Claude HTTP/key rotation/tool and provider timeline fixtures; no live entitlement claim |
| Claude workspace configuration | PC `anthropic_workspace_id`; Mobile safe editor and shared setting | P / P / P | authenticated server roundtrip + widget save tests |
| Claude subscription login | No approved implementation on either client | U / U / U | no login or SDK agent introduced |
| Other configured providers / capability indicators | PC inventory/capability metadata; Mobile selector and attachment checks | P / P / P | non-DeepSeek, catalogue and provider timeline fixtures |
| Authentication errors / credential privacy | PC credentials; safe presence/count/status snapshots only | P / P / P | WOR-308 config redaction; account/parser fixtures |
| Technically available tools / dispatch authority | Canonical selected model and PC dispatcher; Mobile only user controls/projection | P / P / P | canonical runtime, ActionTruth and provider boundaries; no local routing restriction added |
| Tool progress, execution facts and results | `execution_trace`, browser/document progress and canonical answer stream | P / P / P | trace/progress and canonical stream tests; no tool-to-Thinking narrative |
| ToolAttempt / ActionTruth / OUTCOME_UNKNOWN | PC-owned ledger and durable correlated event order; no Mobile truth store | P / P / P | durable ActionTruth tests; unknown remains unknown and new calls remain possible |
| Retry, cancellation and stale receipts | PC binding checks and exact request/run identities | P / P / P | cancellation, suffix replay, stale-route and unknown-effect tests |
| Absolute system-destruction guard | Existing PC terminal guard remains authoritative | P / P / P | unchanged source; Mobile cannot bypass dispatcher |
| Images/screenshots as inputs | PC image artifacts and local source capabilities; Mobile byte transfer | P / P / P | PC attachment and image/provider fixtures; no phone camera success claimed |
| Files/documents/PDF | PC document/source owner; Mobile chunk/upload/manifest protocol | P / P / P | modern + legacy uploads, name/order/hash/cleanup and attachment metadata tests |
| OCR / audio-file / video-file analysis | PC document identity/runtime decides support and results; Mobile forwards supported opaque file inputs | P / P / P | source projection and shared generic transfer; actual OCR codecs/media engines/live analysis NOT_TESTED |
| Upload progress, cancellation, invalid format and errors | Transactional batch state/receipts; Mobile transfer cancellation and composer state | P / P / P | attachment services/composer/server transaction suites |
| Microphone capture and STT | Phone records WAV, PC transcribes; shared STT/fallback/model settings | P / D / D | audio lifecycle/settings fixtures; physical permissions and microphones NOT_TESTED |
| TTS provider/voice/read-aloud/queued audio/Stop | PC synthesis; Mobile playback queue and request correlation | P / P / P | streaming TTS, queue, abandoned-audio and new payload contract test |
| Live API | Existing disabled future capability | U / U / U | remains disabled; no activation |
| Theme palette/shared appearance | PC `ui_theme`; Mobile theme snapshot/write with local startup cache | P / P / P | WOR-232, WOR-238, contrast and live theme update tests |
| UI language/client locale | Native localized surface preference; subsequent requests carry current Mobile locale | D / D / D | six languages; new locale listener test; PC language is not silently overwritten |
| Personality/skills/memory | PC canonical files/store and edit messages; Mobile settings/memory screens | P / P / P | personality/skills guard and memory/config tests |
| Provider config/account/model settings | PC settings owner; Mobile existing set/get controls and live status | P / P / P | provider/settings/reconnect tests, workspace and badge fixes |
| Notifications and background preference | Canonical PC task events; native phone delivery preference/permissions | P / D / D | notification service and settings tests; OS delivery NOT_TESTED |
| Guides/onboarding/privacy/legal/status | Shared manifests/content; native settings/navigation and heartbeat | P / P / P | guide/manifest/legal/localization/heartbeat tests |
| Connectors discover/enable/connect/disconnect/reconnect | PC MCP manager and safe config/status; Mobile OAuth URL/control projection | P / P / P | Gmail native connector, OAuth URL, status/reconnect and credential redaction tests |
| Connector OAuth credentials | PC-only token store; Mobile gets authorization/status metadata | P / P / P | safe snapshots and OAuth attempt correlation; real provider consent NOT_TESTED |
| Scheduled tasks list/create/edit/enable/delete | PC scheduler on canonical Chat; Mobile `cron_jobs` management only | P / P / P | scheduled tasks and Mobile settings fixtures; task instructions retain PC redaction rules |
| Task execution/delivery/failure/history | PC run/notification facts and linked canonical conversation; Mobile notification projection | P / P / P | notification dedup and task status fixtures; no Mobile scheduler |
| QR/token pairing | PC pairing identity; Mobile scanner/token controls | P / D / D | QR/token and credential storage fixtures; phone cameras NOT_TESTED |
| LAN direct / certificate pin / E2E | PC gateway and single transport lease; Mobile LAN service | P / P / P | real local WSS/E2E harness, Windows ACL tests, Dart LAN tests |
| WebRTC/P2P and relay fallback | PC transport manager; Mobile coordinator; same canonical server | P / P / P | signaling, encryption, commit/ownership, fallback, chunk and reconnect suites |
| Reconnect after phone wake / network loss / PC restart | Durable PC event cursors/ACK + Mobile lifecycle hydration | P / P / P | deterministic lifecycle/replay tests; physical PC-restart phone scenario NOT_TESTED |
| Duplicate event suppression / stale callbacks | Exact envelope/request/stream identity; no semantic action anti-replay veto | P / P / P | durable transport and ActionTruth tests |
| Native navigation/keyboard/loading/errors/accessibility | Flutter Chat, input, selectors and settings adapt the shared controls | D / D / D | widget navigation, 50 roundtrips, semantics, 320 px overflow and reduced-motion tests |
| Always-on background connection | Platform-aware service, opt-in Android foreground service; iOS OS lifecycle | D / D / D | Android service and iOS-hidden-toggle fixtures; no continuous iOS socket guarantee |
| Desktop-specific service/autostart/window/browser controls | PC platform owner, not duplicated as a Mobile runtime | D / D / D | unchanged platform boundaries |

## Verification and security

Mobile final full suite: **505 passed, 1 skipped** (explicit live relay diagnostic).
Full `flutter analyze --no-pub`: **no issues**. New focused tests first reproduced
the quota, reasoning, workspace, stale-provider-list, locale and Markdown defects.
After the operator's PC restart, the shared isolated Python regression passed
**454 tests** (one pytest plugin-rewrite warning). The full Flutter suite was
also rerun after restart: **505 passed, 1 skipped**. Final delivery references
are posted in WOR-347.
Additional image/provider and MCP/OAuth checks: **53 passed, 1 skipped**. The skip
is the pre-existing legacy hierarchy seam replaced by route-bound provider
retries; it was not re-enabled to make an obsolete architecture pass.
Focused PC checks include 206 core parity/provider/ActionTruth regressions,
68 Thinking/lifecycle checks, 26 LAN/WebRTC checks and 48 upload tests; these runs
overlap and must not be added together as a unique-test count.

An initial broad Python run exposed a removed `model_has_vision` mock, stale
DeepSeek fixture, assumptions about default-off WebRTC, fixed-sleep timing and raw
file paths/data URI. Tests now exercise current canonical behavior rather than
restoring the removed behavior. Upload fixtures use scratch stores and valid PNG
bytes and verify opaque-source contents under the real owner scope. A run through
stdin passed 453 tests but could not spawn the Windows multiprocessing lease test
because `<stdin>` is not an importable script; the final rerun uses a saved guarded
runner. Interrupted or failed attempts are not passing evidence.

All changed Python files were compiled and touched modules imported. Diff checks
and explicit staged-file reviews passed. Mobile's full deterministic secret scan
and its security-policy tests passed. PC candidate files passed the same scanner
with existing exact fixture exceptions only; no allowlist was broadened. The PC
whole-checkout scan also reported pre-existing untracked benchmark/evidence
archives, runtime stores and fixture copies. It is **not** a clean whole-checkout
security result. Those paths were preserved, not staged, and no secret values
were printed or committed. GitHub main was advanced only through normal pushes.

## Commits (normal pushes to main)

| Repository | Commit | Validated change |
| --- | --- | --- |
| Mobile | `e5aa781f8fcddc9af39175a08078d8119440314f` | V5 real-Chat lifecycle coverage |
| Mobile | `65ca4536003cec3fba65614a062841ee5d0e2a0b` | remaining quota windows |
| Mobile | `8e332ef8bff20daf462bf8c7c087b4ea2204164d` | runtime reasoning IDs |
| Mobile | `a398be7225748fd6a0d5f34a35b5d01862099be7` | Claude workspace UI |
| PC | `cb3cfd4d5853fb25e8345322aca193c24b6a240d` | Claude workspace shared setting |
| PC | `7b3f79171d5ebda0f3caed7ed5b86547f40468f8` | canonical catalogue fixtures |
| Mobile | `600729fd18762594004e28ba98f8adbdb33b104a` | GFM / literal user text / audio behavior test |
| Mobile | `05d99ab5fb39c1a223723cc1794bf0f98b082d0f` | live provider list freshness |
| Mobile | `bb3acd190ec585043cc43ecc4fa729356e20ad7a` | current request locale |
| PC | `cdd6d76896016d4f900f50a7676cef31ea183223` | Windows LAN ACL probe environment |
| PC | `8e187ef17dfc74c13f617f9f5e4abd2a51c5f6bc` | isolated current upload contracts |

## Build provenance and remaining acceptance

Source version remains **1.1.2+16**. Existing local Android release APK is
`space.osia.app`, versionName `1.1.2`, versionCode `16`, minSdk 24, targetSdk 36;
artifact mtime is 7 October 2026. SHA-256:
`974DFF5AB397A85A25E6695178DFF1A16D8CD8C45AA1EB810A9B5193C4B7F133`.
It predates V5 and has no verified source SHA. It was not replaced or distributed.
The iOS project identity is `space.osia.app`, deployment target 13.0. Old functional
TestFlight Internal observations do not verify the new source or its binary.

`adb devices -l` and Flutter device inventory found no phone. No Android native
build, iOS/Xcode compile, signed archive, physical permissions, real OAuth consent,
live provider entitlement, live media processing or phone-network transition was
validated. These remain NOT_TESTED; iOS compilation is BLOCKED on an appropriate
macOS/Xcode build host and device acceptance on an available phone.

WOR-348 must create fresh private test binaries from the verified final primary,
assign build numbers above every existing internal build, record SHA/signature/
hash and run [the operator checklist](WOR-348-phone-validation.md). No automatic
TestFlight upload or public distribution is authorized by this delivery. Keep
WOR-348 open and record the operator's explicit acceptance separately.
