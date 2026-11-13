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

## Round 2: icon + memory
- App icon (light / dark / tinted) installed in `AppIcon.appiconset`; master copy is `MyPal-icon-1024.png`.
- Pal memory is now three layers:
  1. Live `LanguageModelSession` per pal (full in-context turn history).
  2. Recent window: the last 10 messages are replayed verbatim whenever a session is rebuilt
     (relaunch, edited instructions, deleted message, or automatically every 5 turns, before the ~4K-token window fills).
  3. Long-term memory (`Core/MemoryStore`): a rolling summary + up to 12 lasting facts about the person, built in the
     background by a second model session using guided generation (`MemoryUpdate`). Stored per pal as JSON in
     Application Support, injected into the pal's instructions together with today's date.
- Pal editor → Memory section shows what the pal knows and lets you forget it. Clearing a conversation also wipes memory.

## Round 3: ideas.md first sprint
- **Pal identity**: optional emoji + color per pal (editor → Appearance). Core Data model is now versioned
  (`MyPal 2.xcdatamodel`, adds `Pal.emoji` / `Pal.colorName`; lightweight migration). The person's bubbles and send button use the pal's color.
- **Editable memory**: `PalMemory.pinnedFacts` are facts the person added (editor field or "Remember This" on a message);
  the summarizer never removes them. Any fact can be swiped away. Edits go through `PalActions.editMemory`.
- **Suggestions**: conversation starters in an empty chat and three follow-up chips after each reply
  (`@Generable ReplySuggestions`). Toggle in Settings.
- **Voice**: mic button in the composer (on-device `SFSpeechRecognizer` when supported), "Read Aloud" on replies,
  and an optional auto-read setting. Adds microphone + speech recognition usage strings.
- **Siri / Shortcuts**: `AskPalIntent` ("Ask Mentor in MyPal") runs through the pal's `ChatViewModel`, so the
  exchange is saved and remembered like a normal chat.
- **Chat actions**: Regenerate the newest reply, Edit & Resend the newest prompt, Export Conversation as Markdown.
- Removed unused `Core/Instructions.swift`.
