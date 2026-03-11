import WidgetKit
import SwiftUI

// MARK: - Widget Data Model

struct WidgetData: Codable {
    let treeState: String
    let treeEmoji: String
    let entryCount: Int
    let progress: Double
    let stateName: String
    let stateDescription: String
    let recentEntries: [WidgetEntry]
    let lastUpdated: String

    struct WidgetEntry: Codable {
        let id: Int
        let preview: String
        let type: String
        let date: String
    }

    static var placeholder: WidgetData {
        WidgetData(
            treeState: "seed",
            treeEmoji: "🌱",
            entryCount: 0,
            progress: 0.0,
            stateName: "Seed",
            stateDescription: "Every memory starts as a seed",
            recentEntries: [],
            lastUpdated: ISO8601DateFormatter().string(from: Date())
        )
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    private let appGroupId = "group.com.seedling.seedling"

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), widgetData: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), widgetData: loadWidgetData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let currentDate = Date()
        let widgetData = loadWidgetData()
        let entry = SimpleEntry(date: currentDate, widgetData: widgetData)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWidgetData() -> WidgetData {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            return .placeholder
        }

        // Read individual values saved by home_widget
        let treeState = userDefaults.string(forKey: "treeState") ?? "seed"
        let treeEmoji = userDefaults.string(forKey: "treeEmoji") ?? "🌱"
        let entryCount = userDefaults.integer(forKey: "entryCount")
        let progress = userDefaults.double(forKey: "progress")
        let stateName = userDefaults.string(forKey: "stateName") ?? "Seed"
        let stateDescription = userDefaults.string(forKey: "stateDescription") ?? "Every memory starts as a seed"
        let lastUpdated = userDefaults.string(forKey: "lastUpdated") ?? ""

        // Parse recent entries JSON
        var recentEntries: [WidgetData.WidgetEntry] = []
        if let entriesJson = userDefaults.string(forKey: "recentEntries"),
           let data = entriesJson.data(using: .utf8) {
            recentEntries = (try? JSONDecoder().decode([WidgetData.WidgetEntry].self, from: data)) ?? []
        }

        return WidgetData(
            treeState: treeState,
            treeEmoji: treeEmoji,
            entryCount: entryCount,
            progress: progress,
            stateName: stateName,
            stateDescription: stateDescription,
            recentEntries: recentEntries,
            lastUpdated: lastUpdated
        )
    }
}

// MARK: - Timeline Entry

struct SimpleEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "FAF8F5"), Color(hex: "F5F0E8")],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 8) {
                // Tree emoji
                Text(entry.widgetData.treeEmoji)
                    .font(.system(size: 44))

                // Entry count
                Text("\(entry.widgetData.entryCount)")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "2D5A3D"))

                Text("memories")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "6B8E6B"))
            }
        }
        .widgetURL(URL(string: "seedling://home"))
    }
}

struct MediumWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "FAF8F5"), Color(hex: "F5F0E8")],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 16) {
                // Left side: Tree and count
                VStack(spacing: 4) {
                    Text(entry.widgetData.treeEmoji)
                        .font(.system(size: 48))

                    Text("\(entry.widgetData.entryCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "2D5A3D"))

                    Text(entry.widgetData.stateName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "6B8E6B"))
                }
                .frame(width: 80)

                // Divider
                Rectangle()
                    .fill(Color(hex: "D4C5B0").opacity(0.5))
                    .frame(width: 1)

                // Right side: Progress and recent entry
                VStack(alignment: .leading, spacing: 8) {
                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Growth Progress")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "8B7355"))

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "E8E0D5"))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "4A7C59"))
                                    .frame(width: geometry.size.width * entry.widgetData.progress)
                            }
                        }
                        .frame(height: 8)
                    }

                    // Recent entry preview
                    if let recent = entry.widgetData.recentEntries.first {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "8B7355"))

                            Text(recent.preview)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "3D3D3D"))
                                .lineLimit(2)
                        }
                    } else {
                        Text("Tap to add your first memory")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8B7355"))
                            .italic()
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .widgetURL(URL(string: "seedling://home"))
    }
}

struct LargeWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "FAF8F5"), Color(hex: "F5F0E8")],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 12) {
                // Header with tree
                HStack {
                    Text(entry.widgetData.treeEmoji)
                        .font(.system(size: 40))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.widgetData.stateName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "2D5A3D"))

                        Text("\(entry.widgetData.entryCount) memories")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "6B8E6B"))
                    }

                    Spacer()

                    // Add button
                    Link(destination: URL(string: "seedling://capture")!) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "4A7C59"))
                    }
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "E8E0D5"))

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "4A7C59"), Color(hex: "6B9E7B")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * entry.widgetData.progress)
                        }
                    }
                    .frame(height: 10)

                    Text(entry.widgetData.stateDescription)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8B7355"))
                        .italic()
                }

                Divider()
                    .background(Color(hex: "D4C5B0"))

                // Recent entries list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Memories")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "5D5D5D"))

                    if entry.widgetData.recentEntries.isEmpty {
                        Text("No memories yet. Tap + to start.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8B7355"))
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(entry.widgetData.recentEntries.prefix(3), id: \.id) { recent in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(typeColor(recent.type))
                                    .frame(width: 8, height: 8)

                                Text(recent.preview)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "3D3D3D"))
                                    .lineLimit(1)

                                Spacer()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(16)
        }
        .widgetURL(URL(string: "seedling://home"))
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "photo": return Color(hex: "6B8E9F")
        case "voice": return Color(hex: "9F8B6B")
        case "object": return Color(hex: "8B6B9F")
        case "release": return Color(hex: "9F6B7B")
        default: return Color(hex: "4A7C59")
        }
    }
}

// MARK: - Widget Configuration

@main
struct SeedlingWidget: WidgetBundle {
    var body: some Widget {
        SeedlingTreeWidget()
    }
}

struct SeedlingTreeWidget: Widget {
    let kind: String = "SeedlingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Seedling")
        .description("See your memory tree and recent entries.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SimpleEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview Provider

struct SeedlingWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = WidgetData(
            treeState: "sapling",
            treeEmoji: "🌳",
            entryCount: 47,
            progress: 0.53,
            stateName: "Sapling",
            stateDescription: "Growing stronger with each moment",
            recentEntries: [
                .init(id: 1, preview: "Morning walk in the park", type: "line", date: "2025-01-30T08:30:00Z"),
                .init(id: 2, preview: "Coffee with mom", type: "photo", date: "2025-01-29T14:00:00Z"),
                .init(id: 3, preview: "Voice memo from dad", type: "voice", date: "2025-01-28T10:15:00Z"),
            ],
            lastUpdated: "2025-01-30T12:00:00Z"
        )
        let entry = SimpleEntry(date: Date(), widgetData: sampleData)

        Group {
            SmallWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            MediumWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            LargeWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
