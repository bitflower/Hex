# AI Transcription Refinement — iOS Proposal

**Version:** 0.1 draft
**Target:** iOS 26+, iPhone 16 Pro and later
**Status:** Proposal

---

## Problem

Raw voice transcription is noisy — filler words, run-on sentences, misrecognized terms. Users currently have to manually clean up text before sharing or saving. This friction undermines the speed advantage of voice input.

---

## Proposal

After each transcription completes, run the raw text through Apple's on-device Foundation Models framework to produce a cleaned-up version. The raw text appears immediately; a spinner signals background processing; once the LLM finishes, a toggle activates so the user can switch between **Original** and **Refined**.

### Why Apple Foundation Models

- **No bundled model.** The on-device LLM ships with iOS 26 on supported hardware (A17 Pro+). Zero download, zero disk cost to the user.
- **No new framework dependency.** It's a first-party Apple API — fits the sandbox, no extra entitlements beyond what Hex already has.
- **Hardware gate matches our target.** iPhone 16 Pro (A18 Pro) is comfortably within the supported device list; we don't need to manage fallback models.
- **Privacy story is unchanged.** All inference stays on-device, matching Hex's existing promise.

---

## UX Flow

```
1. User holds Record button → audio recording starts
2. User releases → transcription runs (Parakeet / Whisper)
3. TranscriptionResultView appears with raw text immediately
4. Spinner + "Refining..." label appears below the toggle area
5. User can already read, edit, or copy the raw text
6. LLM finishes → spinner disappears, toggle activates
7. User taps "Refined" to see the cleaned version
8. Either version can be copied, shared, or saved to Notes
```

### TranscriptionResultView — States

**State A: Processing**

```
┌─────────────────────────────────────────┐
│                                    [X]  │
│   [ Original ●  |  Refined (dim) ]      │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │  So um I was thinking we should   │  │
│  │  probably move the the endpoint   │  │
│  │  to uh the new cluster...         │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│   ◌ Refining...                         │
│                                         │
│  [Copy]  [Share]  [New Note]  [Append]  │
└─────────────────────────────────────────┘
```

- Toggle is visible but "Refined" segment is disabled/dimmed
- Raw text is fully interactive (editable, selectable, copyable)
- Spinner + "Refining..." sits unobtrusively below the toggle

**State B: Ready**

```
┌─────────────────────────────────────────┐
│                                    [X]  │
│   [ Original  |  Refined ● ]           │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │  I was thinking we should move    │  │
│  │  the endpoint to the new          │  │
│  │  cluster.                         │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│                                         │
│  [Copy]  [Share]  [New Note]  [Append]  │
└─────────────────────────────────────────┘
```

- Toggle is fully active; tapping switches instantly between versions
- Defaults to showing Refined once available (single subtle transition)
- Both versions support all actions (Copy, Share, Notes)

**State C: Refinement failed or unavailable**

```
┌─────────────────────────────────────────┐
│                                    [X]  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Raw transcription text...        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [Copy]  [Share]  [New Note]  [Append]  │
└─────────────────────────────────────────┘
```

- No toggle shown at all — the view looks exactly like today
- Silent failure; no error toast or alert. The feature simply isn't there.

---

## Settings

A single new section in the existing iOS Settings tab:

```
┌─────────────────────────────────────────┐
│  AI Refinement                          │
│                                         │
│  Enable Refinement          [toggle: ON]│
│                                         │
│  Instructions                           │
│  ┌───────────────────────────────────┐  │
│  │ Clean up the transcription. Fix   │  │
│  │ grammar, remove filler words,     │  │
│  │ keep the original meaning.        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Custom Replacements                    │
│  "Emmelix"        →    "MLX"           │
│  "core Emmel"     →    "Core ML"       │
│  [+ Add]                                │
│                                         │
│  [Reset to Defaults]                    │
└─────────────────────────────────────────┘
```

- **Enable toggle** — global on/off. Off by default until the user opts in (or on by default — your call, but having the toggle matters).
- **Instructions** — free-text field. Ships with a sensible default. This becomes the system prompt sent to the model.
- **Custom Replacements** — structured term pairs. Appended to the prompt at runtime so the LLM knows domain-specific corrections. Kept separate from the free-text field for ease of editing.
- **Reset to Defaults** — restores the shipped prompt and clears custom replacements.

---

## Architecture

### New TCA Components

```
IOSAppFeature
  ├── IOSTranscriptionFeature  (existing)
  │     └── triggers refinement after transcription completes
  ├── RefinementFeature         (NEW)
  │     ├── State: status (.idle | .processing | .completed(String) | .failed)
  │     ├── Action: .refine(rawText) | .refinementCompleted(String) | .refinementFailed
  │     └── delegates back to transcription feature
  ├── HistoryFeature            (existing, extended)
  ├── IOSSettingsFeature        (existing, extended)
  └── ModelDownloadFeature      (existing, unchanged)
```

### New Dependency Client

```swift
// RefinementClient.swift
struct RefinementClient {
    /// Check if on-device Foundation Models are available on this hardware
    var isAvailable: @Sendable () -> Bool

    /// Refine raw transcription text using the on-device LLM
    var refine: @Sendable (
        _ rawText: String,
        _ instructions: String,
        _ replacements: [TermReplacement]
    ) async throws -> String
}
```

The live implementation calls Apple's `FoundationModels` framework:

```swift
import FoundationModels

extension RefinementClient {
    static let live = RefinementClient(
        isAvailable: {
            SystemLanguageModel.default.isAvailable
        },
        refine: { rawText, instructions, replacements in
            let session = LanguageModelSession()

            let replacementBlock = replacements
                .map { "\"\($0.from)\" → \"\($0.to)\"" }
                .joined(separator: "\n")

            let prompt = """
            \(instructions)

            \(replacementBlock.isEmpty ? "" : "Apply these term replacements:\n\(replacementBlock)\n")
            Transcription to refine:
            \"\"\"\n\(rawText)\n\"\"\"

            Return only the refined text.
            """

            let response = try await session.respond(to: prompt)
            return response.content
        }
    )
}
```

### Integration with IOSTranscriptionFeature

The refinement triggers inside the existing transcription flow, after raw text is produced:

```swift
// Inside IOSTranscriptionFeature reducer, after successful transcription:
case let .transcriptionCompleted(rawText):
    state.transcriptionResult = rawText
    // Kick off refinement in parallel
    if state.refinementEnabled && refinementClient.isAvailable() {
        state.refinementStatus = .processing
        return .run { send in
            let refined = try await refinementClient.refine(
                rawText,
                settings.refinementInstructions,
                settings.termReplacements
            )
            await send(.refinementCompleted(refined))
        } catch: { error, send in
            await send(.refinementFailed)
        }
    }
    return .none
```

### Data Model Changes

**HexSettings** — add:

```swift
var refinementEnabled: Bool = true
var refinementInstructions: String = "Clean up this voice transcription. Fix grammar, remove filler words (uh, um, you know), and simplify sentences. Keep the original meaning and tone."
var termReplacements: [TermReplacement] = []

struct TermReplacement: Codable, Identifiable, Sendable, Equatable {
    var id: UUID = .init()
    var from: String
    var to: String
}
```

**Transcript** (in HexCore) — add:

```swift
struct Transcript: Codable, Identifiable, Sendable {
    var id: UUID
    var timestamp: Date
    var text: String           // raw transcription (unchanged)
    var refinedText: String?   // LLM output, nil if refinement was off or failed
    var audioPath: URL
    var duration: TimeInterval
    var sourceAppBundleID: String?
    var sourceAppName: String?
}
```

This means history items also carry the refined version. When viewing a history item, the toggle reappears if `refinedText != nil`.

### Prompt Construction

At runtime, the client assembles:

```
{user's instructions from Settings}

Apply these term replacements:
"Emmelix" → "MLX"
"core Emmel" → "Core ML"

Transcription to refine:
"""
{raw transcription}
"""

Return only the refined text.
```

The instructions field is the single knob users turn. Term replacements are a convenience shortcut that gets appended automatically — users who prefer can put everything in the instructions field directly.

---

## Edge Cases

| Scenario | Behavior |
|---|---|
| Empty transcription | Refinement does not trigger |
| Device doesn't support Foundation Models | Toggle never appears; feature is invisible |
| LLM returns empty string | Treat as failure; show raw text only, no toggle |
| LLM takes >10 seconds | No timeout — let it finish. User already has raw text and can dismiss/copy at any time |
| User edits raw text while refinement is in-flight | Refinement result still based on original raw text; user's edits are preserved in the Original tab |
| User dismisses result view before refinement completes | Cancel the in-flight task. If history is on, save raw text only (no refined) |
| User starts new recording before refinement completes | Cancel previous refinement. New session starts clean |
| Append recording after refinement completed | Re-trigger refinement on the full combined text; toggle resets to processing state |
| Refinement is off in Settings | No spinner, no toggle — view looks identical to current app |

---

## What Changes in Existing Code

| File | Change |
|---|---|
| `IOSTranscriptionFeature.swift` | Add `refinementStatus` state, trigger refinement after transcription, handle completion/failure |
| `TranscriptionResultView.swift` | Add segmented toggle (Original / Refined), spinner, display logic based on refinement status |
| `IOSSettingsFeature.swift` | Add refinement section (enable toggle, instructions editor, term replacements) |
| `IOSSettingsView.swift` | Render the new settings section |
| `HexSettings.swift` | Add `refinementEnabled`, `refinementInstructions`, `termReplacements` |
| `TranscriptionHistory.swift` | Add `refinedText: String?` to `Transcript` |
| `IOSHistoryView.swift` | Show toggle on history items that have `refinedText` |
| `HistoryFeature.swift` | Surface `refinedText` for copy/share/notes actions |

### New Files

| File | Purpose |
|---|---|
| `HexiOS/Clients/RefinementClient.swift` | TCA dependency wrapping Foundation Models |
| `HexiOS/Views/RefinementToggle.swift` | Reusable toggle + spinner component used in both result view and history |

---

## Out of Scope (v1)

- macOS support (Foundation Models framework availability on macOS TBD)
- Streaming / partial refinement display
- Multiple refinement styles (e.g., "formal" vs "casual")
- Refinement of history items that were transcribed before the feature existed
- Syncing prompt settings across devices

---

## Open Questions

1. **Default on or off?** Showing the feature by default increases discovery but adds processing to every transcription. Recommend: on by default, since it's non-blocking and the user already has raw text instantly.
2. **Auto-switch to Refined?** When refinement completes, should the view auto-switch to Refined, or stay on Original and just enable the toggle? Recommend: auto-switch with a subtle animation, since that's the whole point. User can always tap back.
3. **Notes integration** — when saving to Apple Notes, should it save the currently-displayed version (Original or Refined), or always the refined version? Recommend: save whichever is currently shown.
4. **Append recording** — re-triggering refinement on the combined text means a second LLM call. Acceptable given it's ~1-2s. Alternative: only refine the appended segment and concatenate. Recommend: re-refine the full text for coherence.
