import Foundation

// Sample data has typical lengths, so each skeleton takes the space its content will.

struct Person: Codable, Hashable {
    var name: String
    var handle: String
    var bio: String
    var initials: String

    static let sample = Person(
        name: "Sample Person", handle: "@samplehandle",
        bio: "A bio of a usual length, long enough to wrap onto a second line on a phone.",
        initials: "SP"
    )
    static let real = Person(
        name: "Ada Lovelace", handle: "@ada",
        bio: "Writes programs for an engine nobody has built yet. Her notes run longer than the paper.",
        initials: "AL"
    )
    static let longer = Person(
        name: "Ada Lovelace", handle: "@ada",
        bio: "Writes programs for an engine nobody has built yet. Her notes run three times longer than the paper they annotate, and describe a machine that could compose music, if anyone would build it.",
        initials: "AL"
    )
}

struct Article: Codable, Hashable {
    var title: String
    var summary: String
    var author: String
    var readTime: String

    static let sample = Article(
        title: "A headline of usual length",
        summary: "A standfirst that runs to about two lines, the way a real one does on a phone screen.",
        author: "Sample Author", readTime: "4 min read"
    )
    static let real = Article(
        title: "Designing for the wait",
        summary: "Loading states are the first thing people see, and on a slow connection the thing they see most.",
        author: "Grace Hopper", readTime: "4 min read"
    )
}

struct ChatMessage: Codable, Hashable, Identifiable {
    var id: Int
    var text: String
    var mine: Bool
}

struct ChatThread: Codable, Hashable {
    var name: String
    var initials: String
    var messages: [ChatMessage]

    static let sample = ChatThread(name: "Sample", initials: "SA", messages: [
        ChatMessage(id: 0, text: "A question of a typical length?", mine: true),
        ChatMessage(id: 1, text: "A reply of about this length", mine: false),
        ChatMessage(id: 2, text: "A longer reply that runs across a couple of lines in the bubble", mine: false),
        ChatMessage(id: 3, text: "Short one", mine: true),
    ])
    static let real = ChatThread(name: "Ada", initials: "AL", messages: [
        ChatMessage(id: 0, text: "Wait, how does it know how long the text is?", mine: true),
        ChatMessage(id: 1, text: "It lays out sample data unseen", mine: false),
        ChatMessage(id: 2, text: "then traces each line and picture into a skeleton of exactly that shape", mine: false),
        ChatMessage(id: 3, text: "Neat", mine: true),
    ])
}

struct Notice: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var initials: String
    var time: String
    var text: String

    static let sample = (0..<3).map { Notice(id: $0, name: "Name", initials: "N\($0)", time: "1h", text: "A message preview that runs to the edge and is cut") }
    static let real = [
        Notice(id: 0, name: "Grace", initials: "GH", time: "2m", text: "Pushed the new site design, have a look when you can"),
        Notice(id: 1, name: "Alan", initials: "AT", time: "1h", text: "The skeletons shimmer in sync now??"),
        Notice(id: 2, name: "Katherine", initials: "KJ", time: "3d", text: "Naming things is the hardest part, as always"),
    ]
}

struct Track: Codable, Hashable {
    var title: String
    var artist: String
    var elapsed: String
    var length: String
    var progress: Double

    static let sample = Track(title: "Song Title", artist: "Artist Name", elapsed: "0:00", length: "0:00", progress: 0.3)
    static let real = Track(title: "Skeletons", artist: "The Layout Shifts", elapsed: "1:12", length: "3:24", progress: 0.35)
}

struct Stats: Codable, Hashable {
    var revenue: String
    var revenueChange: String
    var customers: String
    var customersChange: String
    var weeks: [Double]

    static let sample = Stats(revenue: "$00,000", revenueChange: "+00.0%", customers: "0,000", customersChange: "+0.0%", weeks: Array(repeating: 0.5, count: 12))
    static let real = Stats(
        revenue: "$48,210", revenueChange: "+12.4%", customers: "2,314", customersChange: "+3.1%",
        weeks: [0.42, 0.5, 0.46, 0.6, 0.55, 0.68, 0.64, 0.72, 0.7, 0.81, 0.78, 0.94]
    )
}

struct Holding: Codable, Hashable, Identifiable {
    var id: String { symbol }
    var symbol: String
    var name: String
    var amount: String
    var value: String
    var change: String
    var up: Bool

    static let sample = (0..<3).map { Holding(symbol: "SM\($0)", name: "Sample Coin", amount: "0.00 SMP", value: "$0,000.00", change: "+0.00%", up: true) }
    static let real = [
        Holding(symbol: "BTC", name: "Bitcoin", amount: "0.42 BTC", value: "$28,410.20", change: "+2.31%", up: true),
        Holding(symbol: "ETH", name: "Ethereum", amount: "3.10 ETH", value: "$9,870.55", change: "-0.84%", up: false),
        Holding(symbol: "SOL", name: "Solana", amount: "48 SOL", value: "$7,104.00", change: "+5.12%", up: true),
    ]
}

struct SettingRow: Codable, Hashable, Identifiable {
    var id: String { title }
    var icon: String
    var title: String
    var detail: String
    var isOn: Bool?

    static let sample = (0..<4).map { SettingRow(icon: "circle", title: "Setting \($0)", detail: "Detail", isOn: nil) }
    static let real = [
        SettingRow(icon: "bell.fill", title: "Notifications", detail: "Banners", isOn: nil),
        SettingRow(icon: "moon.fill", title: "Focus", detail: "", isOn: true),
        SettingRow(icon: "lock.fill", title: "Privacy", detail: "On", isOn: nil),
        SettingRow(icon: "globe", title: "Language", detail: "English", isOn: nil),
    ]
}

struct Quote: Codable, Hashable {
    var text: String
    var by: String

    static let sample = Quote(text: "A sample quote of a typical length.", by: "Sample Person")
    static let real = Quote(text: "Nothing should move when it loads.", by: "The Silhouette README")
}
