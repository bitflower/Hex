# Share Note (Text / Audio) — iOS Proposal

**Version:** 0.2 draft
**Target:** iOS (ThoughtFlow)
**Status:** Proposal
**Created:** 2026-04-22
**Updated:** 2026-04-22 — consolidated text + audio under one Share entry point with an in-app format menu

---

## Problem

Every transcription in ThoughtFlow keeps its source audio (`.wav`, 32-bit float, 16 kHz mono) at `Transcript.audioPath`. The file is already on disk and is used internally for playback and for appending new recordings to an existing note.

Today, users have no way to get that audio out of the app. They can copy or share the **text**, save it to Apple Notes, or play it back — but the underlying recording is effectively trapped. Common reasons a user would want the raw audio:

- Archive the original recording alongside notes stored elsewhere (Drive, Dropbox, iCloud Files).
- Re-run transcription in a different tool or language.
- Send the clip to someone else (voice memo-style) via Messages, Mail, AirDrop.
- Edit or trim in a dedicated audio app (Voice Memos, Ferrite).
- Keep a verbatim record for interviews, meetings, or voice journaling.

---

## Proposal

Add a single **Share** action to each history item. Tapping it opens a small in-app menu offering three choices:

- **Share Text** — the transcript (refined or original, whichever is active)
- **Share Audio** — the underlying `.wav` file
- **Share Both** — text and audio attached together

Each choice hands off to the native iOS share sheet with the appropriate payload, so the user can AirDrop, save to Files, attach to Messages/Mail, send to Voice Memos, etc.

No new storage, no new format conversion, no new permission. The text is already in `Transcript.text` / `Transcript.refinedText`; the audio already lives at `Transcript.audioPath`.

### Why one button + an in-app menu (not a "format picker inside the share sheet")

iOS does not expose a way for a generic `UIActivityViewController` / `ShareLink` caller to put a format switch *inside* the share sheet. Apps that appear to do this (Pages, Numbers, Photos "Options") render their own picker **before** invoking the share sheet. We follow that same pattern.

Compared with alternatives:

- **vs. two separate buttons (`Share Text`, `Share Audio`)** — keeps the row uncluttered, and scales if we later add "Share Transcript as PDF" or similar without bloating the action bar.
- **vs. auto-bundling both items in a single share sheet** — avoids the confusing "Voice Memos also received my transcript" surprise. Keeps the user in control.
- **vs. per-destination payloads via `UIActivityItemSource`** — avoids opaque, app-decides-for-you behavior; avoids brittle special-casing per target app.

### Why a share sheet (not a custom export flow)

- **Zero destination UI to invent.** The native share sheet already renders the targets users care about.
- **Privacy story unchanged.** Nothing leaves the device until the user explicitly picks a destination.
- **Symmetry.** Both payloads (text, audio) flow through the same system mechanism.

---

## UX Flow

```
1. User opens History tab
2. User taps the Share action on a transcript row
3. A small in-app menu appears:
     • Share Text
     • Share Audio
     • Share Both
4. User picks one → native iOS share sheet appears with that payload
5. User picks a destination (Files, AirDrop, Messages, Mail, Voice Memos, …)
6. System handles the rest; the note is unchanged
```

Two taps instead of one, but the extra tap buys the user an explicit choice over what leaves the app.

### Entry points

Two surfaces should expose the action. Both share the same menu + payload logic.

**1. History row — primary surface**

In `IOSHistoryView.swift` → `IOSTranscriptRow`, replace the trailing action-bar slot with a `Menu` button:

```
[Copy] [New Note] [Append] [Play] [Share ▾]
```

- Label: **Share**
- SF Symbol: `square.and.arrow.up`
- Tap → `Menu` with three `ShareLink`s (Text / Audio / Both)

> The existing `Copy` button stays. It's a one-tap power-user affordance for the common case and is distinct from sharing elsewhere.

**2. Transcription result view — secondary surface**

In `TranscriptionResultView`, replace the current single `ShareLink(item: activeText)` with the same `Share ▾` menu so a user can grab text, audio, or both immediately after recording without navigating to History.

> Scope note: if we need to ship in one step, the history-row entry point is the MVP. The post-recording entry point can follow, but staying consistent between the two surfaces is strongly preferred.

### Visual states

**Normal row**

```
┌──────────────────────────────────────────────────┐
│  "I was thinking we should move the endpoint…"  │
│  2:14 PM · 00:37                                 │
│                                                  │
│  [Copy] [New Note] [Append] [Play] [Share ▾]    │
└──────────────────────────────────────────────────┘
```

**Menu expanded**

```
          ┌─────────────────────────┐
          │  Share Text             │
          │  Share Audio            │
          │  Share Both             │
          └─────────────────────────┘
```

**Audio-related items when audio is missing** (corrupt history, file deleted out-of-band)

- `Share Audio` and `Share Both` menu items are disabled (grey).
- `Share Text` remains enabled.
- A footnote/caption under the disabled items reads: "Audio file is no longer available."

**No transcript text yet** (edge case: audio saved but transcription failed)

- `Share Text` is disabled.
- `Share Audio` remains enabled.
- If both are unavailable, the Share button itself is disabled.

---

## Technical Design

### Data already in place

- `Transcript.audioPath: URL` points to the `.wav` file on disk.
- File lives under `~/Library/Application Support/com.kitlangton.Hex/Recordings/<timestamp>.wav` and is retained for the life of the history item (see `TranscriptPersistenceClient`).
- Audio is **not** deleted after transcription; deleting the history item is what removes the file (existing behavior; verify and rely on this).

### Changes required

**1. Share menu (SwiftUI)**

A single `Menu` wraps three `ShareLink`s — one per payload:

```swift
Menu {
    ShareLink(
        item: activeText,
        preview: SharePreview(transcript.displayTitle)
    ) {
        Label("Share Text", systemImage: "doc.text")
    }
    .disabled(activeText.isEmpty)

    ShareLink(
        item: transcript.audioPath,
        preview: SharePreview(
            transcript.displayTitle,
            image: Image(systemName: "waveform")
        )
    ) {
        Label("Share Audio", systemImage: "waveform")
    }
    .disabled(!audioExists)

    ShareLink(
        items: [activeText, transcript.audioPath] as [Any],
        preview: SharePreview(
            transcript.displayTitle,
            image: Image(systemName: "waveform")
        )
    ) {
        Label("Share Both", systemImage: "square.and.arrow.up.on.square")
    }
    .disabled(activeText.isEmpty || !audioExists)
} label: {
    historyActionLabel("Share", systemImage: "square.and.arrow.up")
}
```

Notes:
- `activeText` is the currently visible transcript — `refinedText ?? text`. If refinement is toggled, whichever view is active wins.
- `ShareLink` with a file `URL` produces a proper file share that downstream apps recognize as audio (UTI derived from `.wav`).
- `ShareLink(items:)` with a mixed array lets targets that support multi-item (Mail, Notes, Files) include both; single-item targets (Voice Memos, Messages text field) pick the one they understand. This is fine here because the user has *explicitly* asked for "Both."

**2. Pre-flight file check**

Compute once per row:

```swift
let audioExists = FileManager.default.fileExists(atPath: transcript.audioPath.path)
```

Drive the `.disabled()` modifiers on the audio-bearing menu items from this.

**3. Filename the user sees**

`ShareLink` uses the source URL's filename. `<timestamp>.wav` (e.g. `1745347200.wav`) is unfriendly. Two options:

- **(Preferred)** On share, copy the file to a temp location with a human-readable name derived from the transcript (e.g. `ThoughtFlow 2026-04-22 14-14.wav` or the first few words of the text, sanitized). Delete the temp file after the share sheet is dismissed.
- **(Simpler fallback)** Ship with the raw timestamp filename and iterate.

Recommend the preferred path — the extra ~15 lines of code materially improve the "arrives in Files / Messages" experience. Text has no equivalent filename problem (share sheet uses the string directly).

**4. TCA wiring**

Since `Menu` + `ShareLink` are pure SwiftUI, the row can handle sharing inline without a reducer action — keep `HistoryFeature` untouched for v1. If we add the filename rewrite (item 3), introduce a single `case prepareAudioExport(Transcript)` action that produces the temp URL, then feed it into the `ShareLink`.

Start simple: inline menu on the row. Promote to reducer-driven only when the rewrite lands.

### Out of scope (for this PRD)

- Bulk export of multiple notes at once.
- Converting to `.m4a` / `.mp3` on the fly (keep native `.wav`; users can convert downstream).
- Exporting refined or original transcript **text** as a separate file — text sharing already exists.
- Export presets ("Save to Files by default").
- macOS parity (the macOS app has different storage and a different history surface).

---

## Open Questions

1. **Filename format.** Use `ThoughtFlow YYYY-MM-DD HH-mm.wav`, or derive from the first few words of `refinedText ?? text`? First-words-of-text is more searchable but needs sanitization for filesystem-unsafe characters.
2. **"Share Text" payload when refinement exists.** When a note has both original and refined text, does `Share Text` follow the current toggle state in the UI, or always prefer refined? Default: follow the toggle; use refined when no toggle is visible (history row).
3. **Does "Share Both" include text as a file or inline string?** Inline string (current plan) is simplest. A `.txt` sidecar file would give destinations like Files a cleaner two-file drop, at the cost of complexity. Defer unless users ask.
4. **Should the post-recording `TranscriptionResultView` adopt the same Share menu in v1,** or ship history-only first? Strong preference: ship both together to avoid inconsistency.
5. **Confirm audio retention policy.** Verify the assumption that audio is retained until the history item is deleted, and that deleting the history item removes the audio file. If true, no orphan-cleanup work is needed.

---

## Success Criteria

- A user can, in at most **three taps** from History (row action → menu item → destination), share the text, the audio, or both of any transcribed note to an email, iMessage, AirDrop target, Files, Voice Memos, etc.
- The audio file arrives at the destination with a recognizable, reasonable filename.
- `Share Text` and `Share Audio` menu items are independently available — one being unusable does not block the other.
- No regression in existing Copy / New Note / Append / Play / Delete actions.
- When a payload is missing (no audio file, empty text), the corresponding menu item is disabled with a clear reason — never a crash or a silent no-op.
- History row and post-recording result view both use the same Share menu (consistent affordance).

---

## Implementation Sketch (for planning, not final)

| Area | File | Change |
|---|---|---|
| Reusable menu view + path helpers | `HexiOS/Views/TranscriptShareMenu.swift` (new) | `TranscriptShareMenu` view; `Transcript.resolvedAudioURL()` / `sharePreviewTitle` / `audioExportFilenameBase`; `TranscriptAudioExport: Transferable` (lazy pretty-filename copy); `UIActivityViewController` wrapper for "Share Both" |
| History row UI | `HexiOS/Views/IOSHistoryView.swift` (`IOSTranscriptRow`, ~lines 187–234) | Add a 5th action after Play hosting `TranscriptShareMenu`; factor out `historyActionLabel` so the menu reuses the same VStack styling |
| Post-recording UI | `HexiOS/Views/TranscriptionResultView.swift` (existing `ShareLink(item: activeText)` call) | Swap the single `ShareLink` for `TranscriptShareMenu`; resolve audio URL via `currentTranscriptID` → history lookup (nil when `saveTranscriptionHistory` is off — menu falls back to text-only) |
| Path resolver de-dup | `HexiOS/Features/HistoryFeature.swift` (`playTranscript`) | Replace inlined stale-container-UUID fallback with `transcript.resolvedAudioURL()` |
| Tests | Manual on device | Exercise each of the three menu paths (Text, Audio, Both) against at least one real destination (Files, Messages, Mail) |
| Changeset | `.changeset/*.md` (`minor`) | "Add Share menu (Text / Audio / Both) to history notes on iOS" |

Per `CLAUDE.md`, validate end-to-end on a physical iPhone before the PR lands — the share sheet's destination list differs between Simulator and device, and AirDrop / Voice Memos / Files only surface realistically on hardware. Exercise each of the three menu paths against at least one real destination (e.g., Files for audio, Messages for text, Mail for both).
