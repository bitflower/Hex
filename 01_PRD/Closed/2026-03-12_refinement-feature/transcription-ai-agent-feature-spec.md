# Feature Specification: AI-Powered Transcription Post-Processing Agent

**Version:** 1.0  
**Status:** Draft  
**Platform:** Apple (iOS / macOS via MLX)

---

## Overview

The Transcription Post-Processing Agent is an on-device AI agent that automatically refines raw voice transcription output immediately after dictation ends. It corrects typos, simplifies phrasing, removes filler words, and replaces commonly misunderstood or misrecognized terms — all without leaving the app or sending data to external servers. The original transcription is always preserved and accessible via a toggle.

---

## Goals

- Eliminate manual cleanup of voice-to-text output
- Keep all processing local and private (on-device inference)
- Give users full control over the refinement behavior via a configurable prompt
- Preserve the original transcription for reference or reversion at any time

---

## Core Features

### 1. Automatic Post-Processing on Transcription End

The agent triggers automatically as soon as the transcription session ends (microphone stops / user taps "Done"). There is no additional user action required. The refined text replaces the raw transcription in the primary text view within 1–3 seconds, depending on text length and device capability.

**Processing includes (by default):**
- Typo and grammar correction
- Removal of filler words (e.g., "uh", "um", "you know")
- Sentence simplification without changing meaning
- Replacement of commonly misrecognized domain-specific terms (e.g., model names, technical jargon, product names) defined by the user in the prompt configuration

---

### 2. Centralized Prompt Configuration

A dedicated **Prompt Settings** screen allows users to define and edit the system prompt that controls the agent's behavior. This prompt is the single source of truth for all post-processing logic.

**Configuration UI — Prompt Settings Screen:**

```
┌─────────────────────────────────────────┐
│  ← Prompt Settings                      │
├─────────────────────────────────────────┤
│                                         │
│  Processing Instructions                │
│  ┌───────────────────────────────────┐  │
│  │ Clean up the following voice      │  │
│  │ transcription. Fix typos, remove  │  │
│  │ filler words, simplify sentences. │  │
│  │ Replace "MLX" if written as       │  │
│  │ "Emmelix" or "ML X". Keep the    │  │
│  │ original meaning and tone.        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [Reset to Default]        [Save]       │
│                                         │
│  ─────────────────────────────────────  │
│  Term Replacement Shortcuts             │
│                                         │
│  Misrecognized    →    Correct Term     │
│  "Emmelix"        →    "MLX"            │
│  "core Emmel"     →    "Core ML"        │
│  [+ Add Term]                           │
│                                         │
└─────────────────────────────────────────┘
```

- The prompt is a free-text field with no character limit
- Term replacements are appended to the prompt automatically at runtime
- Changes take effect on the next transcription session
- A "Reset to Default" button restores the factory prompt

---

### 3. Original / Refined Toggle

After processing, users can switch between the **Refined** and **Original** versions of their transcription at any time using a segmented toggle above the text area.

**Text View with Toggle:**

```
┌─────────────────────────────────────────┐
│                                         │
│    [ Refined ●  |  Original  ]          │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │  Refined text appears here after  │  │
│  │  processing. Clean, corrected,    │  │
│  │  and ready to use.                │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ✦ AI-refined  ·  Tap Original to      │
│    compare with raw transcription       │
│                                         │
└─────────────────────────────────────────┘
```

- The toggle persists within the session until the user starts a new recording
- Switching between views is instant (no re-processing)
- Both versions can be copied to the clipboard independently
- A subtle "AI-refined" badge is shown when the Refined view is active to maintain transparency

---

## Technical Implementation

### Model

| Property | Value |
|---|---|
| **Model** | Llama 3.2 3B Instruct (4-bit quantized) |
| **Framework** | MLX (macOS) / Core ML (iOS) |
| **Inference** | On-device, no network required |
| **Recommended hardware** | M1+ (macOS), A17 Pro+ (iOS) |
| **Avg. latency** | ~1–2s for ≤500 words on M2 |

### Inference Pipeline

```
User stops recording
        │
        ▼
Speech-to-Text engine outputs raw transcript
        │
        ▼
Agent reads active system prompt from local config store
        │
        ▼
Prompt + raw transcript → MLX / Core ML inference
        │
        ▼
Refined text stored in session state (original preserved separately)
        │
        ▼
UI updates: Refined view shown, toggle enabled
```

### Prompt Construction at Runtime

The agent assembles the final prompt dynamically:

```
[User-defined system prompt from config]

Additionally, apply these term replacements:
- "Emmelix" → "MLX"
- "core Emmel" → "Core ML"
[...further user-defined replacements]

Transcription to process:
"""
{raw_transcription_text}
"""

Return only the refined text. No explanations, no comments.
```

### Storage

| Data | Storage location |
|---|---|
| Active system prompt | `UserDefaults` / local keychain |
| Term replacement pairs | Local JSON config file (sandboxed) |
| Raw transcription | In-memory session state |
| Refined transcription | In-memory session state |

No transcription data is persisted to disk unless the user explicitly saves a note.

---

## UX Flow Summary

```
1. User records voice memo
         ↓
2. Transcription appears (raw)
         ↓
3. Agent runs automatically (~1–2s)
         ↓
4. Refined text shown · toggle appears
         ↓
5. User reads / copies refined text
         ↓
6. Optionally: toggle to Original to compare
         ↓
7. Optionally: go to Settings → Prompt to adjust behavior
```

---

## Edge Cases & Fallbacks

| Scenario | Behavior |
|---|---|
| Transcription is empty | Agent does not trigger; no processing indicator shown |
| Model fails to load | Raw transcription shown; error indicator with retry option |
| Refined text is longer than original | Warning shown; user can revert to original |
| User edits refined text manually | Toggle locks to current state; original still accessible |
| No model downloaded yet | Prompt to download model shown on first launch |

---

## Out of Scope (v1.0)

- Multi-language support beyond the device's primary language
- Sharing or syncing prompts across devices
- Streaming / partial refinement during transcription
- Server-side model inference

---

## Success Metrics

- Time from recording end to refined text displayed: **< 3 seconds** (p90)
- User toggle usage rate (indicates trust in refinement): **< 30%** (lower = better)
- Prompt configuration adoption: **> 40% of active users** customize at least one term replacement
