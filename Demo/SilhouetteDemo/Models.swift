import SwiftUI

struct Person: Codable, Hashable {
    var name: String
    var handle: String
    var role: String
    var bio: String
    var initials: String

    static let sample = Person(
        name: "Sample Person",
        handle: "@samplehandle",
        role: "Design engineer",
        bio: "A bio of typical length, long enough to wrap onto a second line on a phone.",
        initials: "SP"
    )
    static let real = Person(
        name: "Ada Lovelace",
        handle: "@ada",
        role: "Analyst",
        bio: "Writes the first programs for an engine that doesn't exist yet. Notes longer than the paper they annotate.",
        initials: "AL"
    )
    static let longer = Person(
        name: "Ada Lovelace",
        handle: "@ada",
        role: "Analyst",
        bio: "Writes the first programs for an engine that doesn't exist yet. Her notes run three times longer than the paper they annotate, and they describe a machine that could compose music, if anyone would build it.",
        initials: "AL"
    )
}

struct Post: Codable, Hashable, Identifiable {
    var id: Int
    var author: String
    var initials: String
    var role: String
    var time: String
    var text: String

    static let sample = (0..<3).map {
        Post(id: $0, author: "Sample Name", initials: "SN", role: "Team", time: "1h", text: "A typical post, about this long, with a second line for good measure.")
    }
    static let real = [
        Post(id: 0, author: "Grace Hopper", initials: "GH", role: "Compilers · 1h", time: "1h", text: "Shipped the new shimmer. It finally moves at one pace on every screen size."),
        Post(id: 1, author: "Alan Turing", initials: "AT", role: "Research · 2h", time: "2h", text: "The skeletons are shimmering in sync now??"),
        Post(id: 2, author: "Katherine Johnson", initials: "KJ", role: "Product · 3h", time: "3h", text: "Draft of the docs is ready for a second pair of eyes."),
    ]
}

struct Article: Codable, Hashable {
    var title: String
    var summary: String
    var author: String
    var readTime: String

    static let sample = Article(
        title: "A sample headline of usual length",
        summary: "A standfirst that runs to about two lines, the way a real one does on a phone screen.",
        author: "Sample Author",
        readTime: "4 min read"
    )
    static let real = Article(
        title: "Designing for the wait",
        summary: "Loading states are the first thing people see, and on a slow connection the thing they see most.",
        author: "Margaret Hamilton",
        readTime: "4 min read"
    )
}

struct Stats: Codable, Hashable {
    var revenue: String
    var revenueChange: String
    var customers: String
    var customersChange: String
    var weeks: [Double]
    var activity: [String]

    static let sample = Stats(
        revenue: "$00,000", revenueChange: "+00.0%", customers: "0,000", customersChange: "+0.0%",
        weeks: Array(repeating: 0.5, count: 12),
        activity: ["Someone did a typical thing", "Someone did a typical thing", "Someone did a typical thing"]
    )
    static let real = Stats(
        revenue: "$48,210", revenueChange: "+12.4%", customers: "2,314", customersChange: "+3.1%",
        weeks: [0.42, 0.5, 0.46, 0.6, 0.55, 0.68, 0.64, 0.72, 0.7, 0.81, 0.78, 0.92],
        activity: ["Grace paid invoice #2041", "Alan upgraded to Team", "Katherine requested a refund"]
    )
}

struct Track: Codable, Hashable {
    var title: String
    var artist: String
    var album: String
    var elapsed: String
    var remaining: String
    var progress: Double

    static let sample = Track(title: "Typical Song Title", artist: "Sample Artist", album: "Album", elapsed: "0:00", remaining: "-0:00", progress: 0.3)
    static let real = Track(title: "Clair de Lune", artist: "Claude Debussy", album: "Suite bergamasque", elapsed: "1:42", remaining: "-3:21", progress: 0.34)
}

struct Holding: Codable, Hashable, Identifiable {
    var id: String { symbol }
    var symbol: String
    var name: String
    var amount: String
    var value: String
    var change: String
    var up: Bool

    static let sample = (0..<4).map { Holding(symbol: "SMP\($0)", name: "Sample Coin", amount: "0.00 SMP", value: "$0,000.00", change: "+0.00%", up: true) }
    static let real = [
        Holding(symbol: "BTC", name: "Bitcoin", amount: "0.42 BTC", value: "$28,410.20", change: "+2.31%", up: true),
        Holding(symbol: "ETH", name: "Ethereum", amount: "3.10 ETH", value: "$9,870.55", change: "-0.84%", up: false),
        Holding(symbol: "SOL", name: "Solana", amount: "48 SOL", value: "$7,104.00", change: "+5.12%", up: true),
        Holding(symbol: "DOT", name: "Polkadot", amount: "310 DOT", value: "$1,922.00", change: "+0.40%", up: true),
    ]
}

struct SettingRow: Codable, Hashable, Identifiable {
    var id: String { title }
    var icon: String
    var title: String
    var detail: String
    var isOn: Bool?

    static let sample = (0..<5).map { SettingRow(icon: "circle", title: "Setting \($0)", detail: "Detail", isOn: nil) }
    static let real = [
        SettingRow(icon: "bell", title: "Notifications", detail: "Banners", isOn: nil),
        SettingRow(icon: "moon", title: "Focus", detail: "", isOn: true),
        SettingRow(icon: "lock", title: "Privacy", detail: "On", isOn: nil),
        SettingRow(icon: "icloud", title: "Backups", detail: "", isOn: false),
        SettingRow(icon: "globe", title: "Language", detail: "English", isOn: nil),
    ]
}

struct Quote: Codable, Hashable {
    var text: String
    var by: String

    static let sample = Quote(text: "A sample quote of typical length.", by: "Sample Person")
    static let real = Quote(text: "Nothing should move when it loads.", by: "The Silhouette README")
}

enum Palette {
    static func color(for initials: String) -> Color {
        let colors: [Color] = [.orange, .pink, .teal, .indigo, .mint, .blue, .purple]
        return colors[initials.unicodeScalars.reduce(0) { $0 + Int($1.value) } % colors.count]
    }
}
