# The Cut

Director interview prep for iPhone. Native SwiftUI, offline SwiftData, bundled role packs.

Turns the *Director Interview Prep: Research and Framework* doc into:

- a Reels-style learn feed
- Duolingo-style quizzes (XP, streak, spaced repetition)
- spoken answers via **Pomvox** (on-device raw + cleaned transcripts)
- Claude Opus grading (API key in Keychain, monthly spend cap)
- eight-week course tracker + story bank
- timed system-design / scenario mocks
- live Claude interviewer rounds

## Requirements

- Xcode 16+ / iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen`)
- Anthropic API key for grading / live rounds (Settings)

## Setup

```bash
cd "/Users/maanasa/Documents/theCut /Untitled"
xcodegen generate
open TheCut.xcodeproj
```

Select your Development Team in Signing, then run on a device or simulator. For TestFlight, archive and upload with your personal Apple Developer account.

## Role packs

| Pack | Status |
|------|--------|
| Director's Cut | Shipped (content from the research PDF) |
| Senior Manager's Cut | Shell |
| Manager's Cut | Shell |
| Principal's Cut | Shell |

Content lives in `TheCut/Content/Packs/*.json`. Adding a pack is a new JSON file — no code changes.

## Pomvox

`Packages/PomvoxSpeech` records on device, produces raw + cleaned transcripts (Pomvox cleanup rules), and links FluidAudio for the Parakeet Neural Engine path used by Pomvox.app. When Parakeet is cold, Apple Speech is the on-device fallback. Audio is deleted after transcription and never uploaded.

## Version map

| Version | Features |
|---------|----------|
| 0.1 | Learn feed, favorites, topic filters, Director's Cut |
| 0.2 | Quizzes, XP, streak, daily goals, spaced repetition |
| 0.3 | Spoken answers, Pomvox, Claude grading, Keychain spend cap |
| 0.4 | Course tracker, story bank, SD/scenario mock timers |
| 0.5 | Live Claude interviewer rounds + scorecards |
