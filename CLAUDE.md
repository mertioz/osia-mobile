# OSIA Mobile — Rules for Claude Code

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
