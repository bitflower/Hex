# ThoughtFlow — iOS App Icon Design Brief

## What the App Does

ThoughtFlow is an iOS voice-to-text transcription app. The user taps and holds a large microphone button, speaks, and gets instant on-device transcription. Key features:

- **Voice recording with visual feedback** — a pulsing ripple ring expands around the mic button while recording, turning red to indicate active capture
- **On-device AI transcription** — speech is converted to text locally using machine learning (no cloud required), emphasizing privacy
- **AI refinement** — an optional second pass cleans up the raw transcription using Apple's on-device language model
- **Apple Notes integration** — transcriptions can be saved or appended to Apple Notes via Shortcuts
- **Append recording** — users can keep adding to an existing transcription by recording more
- **History** — all past transcriptions are stored and searchable

The app has three tabs: **Record** (centered mic button), **History** (list of past transcriptions), and **Settings**.

## Core Concepts to Convey

- **Voice / speech** — this is fundamentally about turning spoken words into text
- **Flow / fluidity** — the name "ThoughtFlow" suggests thoughts streaming effortlessly from mind to text
- **Speed & immediacy** — tap, speak, done
- **Privacy / on-device** — everything happens locally on the phone
- **Clean, minimal, focused** — the app is a single-purpose tool, not a Swiss Army knife

## Existing Visual Identity

- The predecessor (macOS version "Hex") uses a **hexagon** as its core shape — a geometric, clean motif
- The app uses **system blue as accent color**, **red for recording state**, **purple sparkles for AI-refined text**, and **orange for Notes integration**
- UI is minimal with generous whitespace, blur materials, and rounded shapes
- SF Symbols used throughout: `mic.fill`, `clock.arrow.circlepath`, `gear`

## Design Direction (Suggestions, Not Constraints)

- Consider incorporating a **speech/sound wave**, **microphone**, or **flowing text** motif
- The "flow" in ThoughtFlow could inspire fluid, wave-like, or gradient elements
- A modern, bold, simple shape works best at small sizes (the icon will appear at 29pt on iPhone)
- Avoid overly detailed illustrations — Apple's HIG favors simple, recognizable silhouettes
- A single strong color or a tasteful gradient tends to stand out on the home screen

## Technical Requirements

| Requirement | Specification |
|---|---|
| **File format** | PNG (no transparency, no alpha channel) |
| **Resolution** | 1024 x 1024 px (the single required asset; Xcode generates all sizes from this) |
| **Shape** | Square with no pre-applied rounding — iOS applies the superellipse mask automatically |
| **Color space** | sRGB or Display P3 |
| **Layers** | Deliver a flattened PNG, but also provide the layered source file (Figma/PSD/AI) |
| **Safe zone** | Keep critical elements within the center ~80% — corners will be clipped by the iOS mask |
| **Background** | Must be opaque (no transparency) — fill the entire 1024x1024 canvas |
| **Do not include** | Rounded corners, drop shadows, or gloss effects (iOS adds these) |
| **Additional deliverable** | An SVG version for potential use in marketing materials |

## Reference

- [Apple Human Interface Guidelines — App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- The icon should look good on light and dark wallpapers
- Test the design at small sizes (29pt, 40pt, 60pt) to make sure it reads clearly
