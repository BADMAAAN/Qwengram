public enum QwengramBotCategory: CaseIterable, Equatable {
    case ai
    case media
    case utilities
    case custom

    public static let allCases: [QwengramBotCategory] = [.ai, .media, .utilities, .custom]
}

public struct QwengramBotDescriptor {
    public let id: String
    public let title: String
    public let subtitle: String
    public let username: String?
    public let category: QwengramBotCategory
    public let isEnabled: Bool

    public init(id: String, title: String, subtitle: String, username: String?, category: QwengramBotCategory, isEnabled: Bool) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.username = username
        self.category = category
        self.isEnabled = isEnabled
    }
}

public enum QwengramBotCatalog {
    public static let defaultBots: [QwengramBotDescriptor] = [
        QwengramBotDescriptor(id: "qwen-assistant", title: "Qwen Assistant", subtitle: "Ask Qwen", username: nil, category: .ai, isEnabled: true),
        QwengramBotDescriptor(id: "summarizer", title: "Summarizer", subtitle: "Summarize text", username: nil, category: .ai, isEnabled: true),
        QwengramBotDescriptor(id: "translator", title: "Translator", subtitle: "Coming soon", username: nil, category: .ai, isEnabled: false),
        QwengramBotDescriptor(id: "media-tools", title: "Media Tools", subtitle: "Coming soon", username: nil, category: .media, isEnabled: false),
        QwengramBotDescriptor(id: "qr-tools", title: "QR Tools", subtitle: "Generate QR codes", username: nil, category: .utilities, isEnabled: true),
        QwengramBotDescriptor(id: "reminders", title: "Reminders", subtitle: "Coming soon", username: nil, category: .utilities, isEnabled: false),
        QwengramBotDescriptor(id: "add-bot", title: "Add Bot", subtitle: "Coming soon", username: nil, category: .custom, isEnabled: false),
    ]
}
