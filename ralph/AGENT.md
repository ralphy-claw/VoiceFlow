# Ralph Agent Instructions — VoiceFlow

You are an autonomous coding agent working on **VoiceFlow**, a personal iOS voice/text tool.

## Tech Stack
- **SwiftUI**, iOS 17+
- **SwiftData** for persistence
- **OpenAI APIs**: Whisper (STT), TTS, GPT-4o-mini (summarization)
- Modern Swift concurrency (async/await, actors)
- Bundle ID: `com.lubodev.voiceflow`
- Team ID: `79NK8S894T`

## Project Structure
- `VoiceFlow/` — Main app source
- `VoiceFlow/ContentView.swift` — Tab-based navigation (Transcribe, Speak, Summarize)
- `VoiceFlow/OpenAIService.swift` — API client (actor-based)
- `VoiceFlow/Config.swift` — API key config (to be replaced by Keychain)

## Quality Gates
```bash
xcodebuild -scheme VoiceFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Build MUST succeed before committing.

## Your Files
- `ralph/.context.md` — GitHub issues, commit history, progress (generated at runtime)
- `ralph/progress.txt` — Progress log (append your learnings here)

## Important
- ONE task per iteration
- Keep builds passing
- Small, focused changes
- APPEND to progress.txt — never replace
- Comment on GitHub issues with progress
- Follow existing code patterns and style

## Stop Condition
If no open issues or remaining tasks:
```
<signal>NO_MORE_TASKS</signal>
```
