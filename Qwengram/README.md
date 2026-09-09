# Qwengram

`Qwengram/` contains Qwengram-only features.

The existing `Nagram/` directory remains the upstream enhancement layer. Do
not mass-edit or rename Nagram code.

Keep the architecture layered:

```text
Telegram upstream
↓
Nagram enhancement layer
↓
Qwengram custom layer
```

If a future upstream modification is unavoidable, mark it with:

```swift
// MARK: QWENGRAM
```

Implemented modules:

- SettingsSignal
- SettingsUI
- Bots (`QwengramBots`)
- AI (`QwengramAI`) foundation with Qwen provider support

QR Tools is the first functional Bots Hub utility: it generates QR codes locally
on-device. No bot-network execution or integration exists yet.

Qwen credentials are stored in Keychain. Qwen Assistant is the first functional
AI entry and requires a user-supplied Qwen API key. It supports streaming text
responses; its conversation remains in-memory only. Attachments and persistence
are not implemented.

Summarizer is functional and uses the configured Qwen provider. Submitted text
and generated summaries remain in-memory only.

Planned modules:
- Privacy
- History
- Media
