# MyPal – production pass

## Architecture
- `Core/MessageStore` – all message I/O on one background context; cursor (timestamp) pagination, batch deletes.
- `Chat/ChatViewModel` – paged history (30/page), one persistent `LanguageModelSession` per pal, streaming kept
  in memory (single Core Data write per reply), stop/retry, prewarm on composer focus, context-overflow recovery.
- Streaming text is isolated from the message list, so each token re-renders one bubble only.
- Markdown: linear-time block parser + `AttributedString` inline styling, cached per message.

## Bugs fixed
- Pals created in the old editor had no `id` (chat showed every message / `palId!` crash). Repaired on launch.
- Deletes that never called `save()`; "Delete" didn't remove the pal's messages.
- Search was never wired up. Default pals were re-seeded on every `Settings()` init.
- Pals now remember the conversation (old code made a new session per message).
- Orphaned "Typing…" placeholders from killed streams are cleaned up on launch.

## UX
- Keyboard: interactive drag-dismiss, tap-to-dismiss, "Done" on form keyboards, dismissed on leave.
- Liquid Glass composer (multi-line, send ⇄ stop), scroll-to-latest button, day separators,
  empty states, confirmations on every destructive action, Apple Intelligence availability banner.
- Pals list: last message preview + timestamp, search, swipe/context actions.
- Pal editor: validation, duplicate-name check, character limit, unsaved-changes guard.

## Removed (still in your git history)
CheckInView, DiscussionView, ReminderView, Settings.swift, printUtils.swift, CoreDataUtils, FoundationModel.

## Still needed from you
- App icon artwork (AppIcon set has no images) and a Team/provisioning check.
- Not compiled in my environment – build once in Xcode 26 and fix any SDK nits.
