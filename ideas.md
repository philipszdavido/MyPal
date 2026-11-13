# MyPal — Ideas

MyPal's edge is that it's **private, on-device, and remembers you**. Most ideas below build on that instead of competing with cloud chatbots on raw intelligence.

Effort: 🟢 small · 🟡 medium · 🔴 large

---

## 1. Make pals feel alive

- ✅ **Pal identity** 🟢 — An emoji/SF Symbol avatar and accent color per pal (needs `avatar`, `color` attributes on `Pal`). Tint the pal's bubbles and composer with its color.
- **Pal templates gallery** 🟢 — Expand `DefaultPals` into a browsable gallery (Coach, Journal Buddy, Language Tutor, Study Partner, Cooking Helper, Debate Partner, Bedtime Storyteller). One-tap "Add" instead of seeding everything up front.
- **Pals that reach out first** 🟡 — Optional daily check-in: a local notification written by the pal ("How did the interview go?"). Use `PalMemory.facts` to make it personal. Bring back the old CheckIn idea, done properly.
- ✅ **Conversation starters** 🟢 — An empty chat shows 3 suggested openers built from the pal's instruction and memory (guided generation, `@Generable [String]`).
- ✅ **Follow-up chips** 🟡 — After each reply, show 2–3 tappable suggested replies. The *Hobbies Pal* already produces short topic lists, so this would fit it naturally.
- **Pal personality knobs** 🟢 — Sliders in the editor for tone (playful ↔ serious) and length (brief ↔ detailed), compiled into the instructions. Easier than writing a prompt from scratch.
- **"Help me write this pal"** 🟢 — In the editor, the user describes a pal in one line and the model drafts the full instruction.

## 2. Memory as the headline feature

- ✅ **Editable memory** 🟢 — Facts are only read-only or "forget all" today. Allow deleting single facts, editing them, and adding your own ("Remember that I'm vegetarian").
- ✅ **"Remember this"** 🟢 — A message context-menu action that pins a fact straight into `PalMemory.facts`.
- **Shared "About me" profile** 🟡 — A global profile in Settings (name, pronouns, interests, goals) given to every pal, so you don't introduce yourself to each one.
- **Memory transparency** 🟢 — A small "🧠 remembered something" indicator when a memory update adds a new fact, linked to the Memory section.
- **Timeline memory** 🟡 — Store dated events ("Started a new job — Mar 2026") so pals can say "it's been a month since…".

## 3. Chat experience

- ✅ **Voice** 🟡 _(dictation + read-aloud done; talk mode and per-pal voices not yet)_ — Dictation in the composer (Speech framework, on-device) and read-aloud replies (`AVSpeechSynthesizer`) with a per-pal voice. A hands-free "talk mode" for walks or driving.
- ✅ **Regenerate and edit** 🟢 — Regenerate the last reply, and edit and resend a user message. The retry plumbing in `ChatViewModel` already exists.
- **Search inside a conversation** 🟡 — Full-text search over `Message.content` with jump-to-result using cursor pagination.
- **Better Markdown** 🟡 — Tables, block quotes, syntax-highlighted code blocks with a copy button, and tappable links.
- ✅ **Haptics and polish** 🟢 — A light haptic when a reply starts and finishes, plus a subtle typing shimmer.
- **Images in** 🔴 — Attach a photo, extract text and labels with Vision on-device, and send them as context ("What can I cook with this?").

## 4. Tools (Foundation Models `Tool` protocol)

Give pals real abilities while keeping everything on-device:

- **Reminders and Calendar** 🟡 — "Remind me to call mom Friday" → EventKit, with confirmation UI.
- **Journal** 🟡 — A pal that saves daily entries and can answer "What was I stressed about last month?"
- **Notes and lists** 🟢 — Pals can create and update checklists (shopping, packing) shown as interactive cards in the chat.
- **Health context (opt-in)** 🔴 — Sleep and steps from HealthKit for a wellness or coach pal.
- **Weather and location** 🟡 — WeatherKit for "Should I run today?".

## 5. Group and multi-pal

- **Pal roundtable** 🔴 — Ask one question to 2–3 pals and get answers side by side (Movie Critic vs Music Critic), or let them debate. Session isolation is already per pal.
- **Hand-off** 🟢 — "Ask Mentor about this": forward a message to another pal with context.

## 6. System integration

- ✅ **App Intents and Siri** 🟡 — "Ask Mentor …" from Siri, Shortcuts, Spotlight, and the Action button.
- **Widgets** 🟡 — A home-screen widget with the latest message or a daily prompt from a pal, and a Lock Screen quick-ask.
- **Share extension** 🟡 — Share text or a URL from any app to a pal ("Summarize this", "What do you think?").
- **Live Activity** 🟢 — For long replies or a timed "focus session with Coach".
- **iPad and Mac** 🟡 — `NavigationSplitView` with the pal list in a sidebar. Mac Catalyst or native macOS gets nearly free reuse.

## 7. Data and trust

- **Export and import** 🟢 _(conversation export done)_ — Export a conversation as Markdown/PDF; export or import pals (`.mypal` JSON) so people can share personas.
- **iCloud sync** 🔴 — `NSPersistentCloudKitContainer`. Needs a model migration first: add a real `Pal ↔ Message` relationship instead of the string `palId`, and make required fields non-optional.
- **App lock** 🟢 — Face ID lock for the app or for individual pals. This fits a journaling or companion app.
- **Privacy screen** 🟢 — A clear "nothing leaves your device" explainer in Settings, which can also be a marketing point.

## 8. Engineering health

- **Tests** 🟡 — Add a test target. Unit-test `MarkdownParser`, the `recap` budget logic, `MemoryStore`, and `MessageStore` against the in-memory `PersistenceController`.
- **Core Data migration** 🟡 — Version the model (relationship, non-optional fields, `avatar` and `color`) using lightweight migration.
- **Split `ChatViewModel`** 🟢 — It's ~500 lines. Pull memory summarization into a `MemoryEngine` and session building into a `SessionBuilder` so they can be tested on their own.
- ✅ **Remove dead code** 🟢 — `Core/Instructions.swift` is unused.
- **Token awareness** 🟡 — Measure prompt size instead of using character heuristics (`maxCharacters: 2400`) when the API allows it, to reduce overflow retries.
- **Fallback model (optional)** 🔴 — Use a user-supplied cloud key when Apple Intelligence is unavailable. It widens reach but weakens the privacy story, so treat it as a product decision.

---

## Suggested first sprint (done, see CHANGES.md Round 3)

1. Pal avatar and color, with the Core Data migration that also adds the relationship
2. Editable memory and "Remember this"
3. Follow-up chips and conversation starters
4. Voice input and read-aloud
5. App Intents ("Ask {pal}") and a widget

These are visible wins that make the app feel personal and native, and they reuse the existing memory system.
