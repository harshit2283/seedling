import AppIntents

@available(iOS 16.0, *)
struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture a Memory"
    static var description = IntentDescription(
        "Open Seedling to capture a quick memory",
        categoryName: "Memory"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today's Memories"
    static var description = IntentDescription(
        "See what you've captured today",
        categoryName: "Memory"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 16.0, *)
struct SeedlingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickCaptureIntent(),
            phrases: [
                "Capture a memory in \(.applicationName)",
                "Add to \(.applicationName)",
                "Remember something in \(.applicationName)"
            ],
            shortTitle: "Capture Memory",
            systemImageName: "leaf.fill"
        )
        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: [
                "Open today in \(.applicationName)",
                "Show today in \(.applicationName)"
            ],
            shortTitle: "Open Today",
            systemImageName: "calendar"
        )
    }
}
