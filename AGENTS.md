# OSIA Mobile — Rules for Codex

## CRITICAL — Do NOT modify these unless explicitly asked:
- `lib/services/websocket_service.dart` — core WebSocket logic (protocol, message types, streaming). Touching this breaks connection/streaming.
- The WebSocket message protocol and message type names
- Conversation persistence logic (list/load/delete/new)
- The model selector flow (get_models/models_list/set_model)

## Before ANY change:
- Only modify the specific files needed for the requested task
- Never refactor or "improve" code outside the scope of the request
- Never change function signatures that other files depend on
- After a change, verify existing features still work (connection, streaming, conversations, model selector)

## When fixing a bug:
- Make the SMALLEST possible change that fixes it
- Do not touch unrelated code paths
- List exactly which files you changed and why

## QUALITY PROTOCOL — DO NOT BREAK EXISTING CODE WHILE FIXING
This section is MANDATORY. Every task MUST follow these rules:

- **Minimal scope**: modify only what is strictly necessary for the task. No out-of-scope refactoring, no unrequested "improvements", no opportunistic cleanups.
- **Identify all usages before modifying**: before changing any class, method, or widget, search the whole project (`lib/`) for every usage and verify none breaks. If a signature changes, update ALL callers in the same change.
- **Verify adjacent features after each fix**: confirm related screens/flows still work (e.g. connection, streaming, conversations, model selector, config/API-keys screens). List exactly what was verified in the summary.
- **`flutter analyze` mandatory on modified files**: zero errors and zero new warnings before considering the task done.
- **Adversarial review for non-trivial changes**: review your own change for correctness, regressions, and AGENTS.md compliance, verifying each finding independently before reporting it as resolved.
- **Preserve existing contracts — these must NEVER regress**:
  - The WebSocket protocol and message type names in `lib/services/websocket_service.dart`.
  - The standalone stream message classes (`ConfigData`, `HeartbeatDataMessage`, `NewChatMessage`, `ConversationsListMessage`, `ApiKeysMessage`) — these are deliberately NOT sealed `OsiaMessage` subtypes, to avoid exhaustive-switch compile errors. Do not fold them into the sealed hierarchy.
  - The model-selector flow (get_models/models_list/set_model).
  - Conversation persistence (list/load/delete/new).
  - The theme: background `#0d0b12` and violet accent `#c4b5f5`.
- **Precise summary**: every task ends with a summary listing files modified, what was verified, and any side effects identified.

**Guiding principle: quality over speed.** A fix that creates a regression elsewhere is a failure, even if it solves the original problem.
