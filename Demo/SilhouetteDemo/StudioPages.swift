import Silhouette
import SwiftUI

// Pages in the style of Halo, the health app built with Silhouette: pastel paper, hairline type,
// photographs that fade into the page, and numbers that read at a glance.

/// The reveal for a recording: `-mode together|sequence|smart|sweep|blur|wipe|focus|unveil|zoom`.
enum DemoReveal {
    static var current: SkeletonReveal { named(UserDefaults.standard.string(forKey: "mode")) }

    static func named(_ name: String?) -> SkeletonReveal {
        switch name {
        case "together": .together
        case "sequence": .sequence
        case "sweep": .sweep
        case "blur": SkeletonReveal(order: .byPosition, enter: .blur, duration: 0.35)
        case "unveil": SkeletonReveal(order: .byPosition, enter: .unveil, duration: 0.35)
        case "zoom": SkeletonReveal(order: .byPosition, enter: .zoom, duration: 0.35)
        case "wipe":
            SkeletonReveal(wipe: .custom { p in wipeDown(p) }, duration: 0.6)
        case "focus":
            SkeletonReveal(wipe: .custom({ p in wipeDown(p) }, effect: { p in .init(blur: 8 * (1 - p), scale: 0.98 + 0.02 * p) }), duration: 0.7)
        default: .smart
        }
    }

    private static func wipeDown(_ p: Double) -> SkeletonReveal.WipeMask {
        let at = p * 1.2
        return .init(stops: [.init(color: .black, location: max(0, at - 0.2)), .init(color: .clear, location: min(1, max(at, 0.001)))])
    }
}

enum Studio {
    static let ink = Color.adaptive(light: Color(red: 0.11, green: 0.11, blue: 0.14), dark: Color(white: 0.96))
    static let quiet = Color.adaptive(light: Color(red: 0.45, green: 0.44, blue: 0.52), dark: Color(white: 0.6))
    static let faint = Color.adaptive(light: Color(red: 0.68, green: 0.67, blue: 0.74), dark: Color(white: 0.38))
    static let rule = Color.adaptive(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08))
    static let mint = Color(red: 0.45, green: 0.8, blue: 0.62)
    static let peach = Color(red: 0.98, green: 0.62, blue: 0.36)
    static let sky = Color(red: 0.55, green: 0.78, blue: 0.98)
    static let lilac = Color(red: 0.62, green: 0.52, blue: 0.9)

    static func photo(_ name: String) -> Image? {
        UIImage(named: name).map { Image(uiImage: $0) }
    }
}

/// A page in the studio style: paper, generous margins, sections that each load on their own.
struct StudioPage<Content: View>: View {
    var reload: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) { content }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 60)
                .contentShape(.rect)
                .onTapGesture(perform: reload)
        }
        .skeletonReveal(DemoReveal.current)
        .skeletonTracksScrolling()
        .background {
            Group {
                if scheme == .dark {
                    Color.black
                } else {
                    LinearGradient(colors: [Color(red: 0.95, green: 0.94, blue: 0.97), Color(red: 0.97, green: 0.95, blue: 0.94)], startPoint: .top, endPoint: .bottom)
                }
            }
            .ignoresSafeArea()
        }
        .task {
            let every = UserDefaults.standard.double(forKey: "autoreload")
            guard every > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(every))
                if !Task.isCancelled { reload() }
            }
        }
    }
}

// MARK: - Today

struct TodayData: Codable, Hashable {
    struct Reading: Codable, Hashable { var label: String; var value: String; var unit: String }
    var name: String
    var readings: [Reading]
    var coach: String
    static let sample = TodayData(name: "Name.", readings: [.init(label: "Sample", value: "88", unit: "unit"), .init(label: "Sample label", value: "−8.8", unit: "°C"), .init(label: "Sample", value: "88", unit: "bpm")], coach: "A line from the coach.")
    static let real = TodayData(name: "Sam.", readings: [.init(label: "Breathing", value: "14", unit: "rpm"), .init(label: "Wrist temp", value: "−0.1", unit: "°C"), .init(label: "Heart", value: "72", unit: "bpm")], coach: "Here's what I see.")
}

struct TodayPage: View {
    @State private var today = DemoLoad { TodayData.real }

    var body: some View {
        StudioPage(reload: today.reload) {
            WeekStrip()
            Skeleton(today.value, sample: .sample) { TodayHero(today: $0) }
            Skeleton(today.value, sample: .sample) { CoachLine(today: $0) }
        }
    }
}

private struct WeekStrip: View {
    var body: some View {
        HStack {
            ForEach(Array(zip(["S", "M", "T", "W", "T", "F", "S"], 8...14)), id: \.1) { day, date in
                VStack(spacing: 6) {
                    Text(day).font(.system(size: 10, weight: .medium)).foregroundStyle(Studio.faint)
                    Text("\(date)")
                        .font(.system(size: 15, weight: date == 11 ? .semibold : .regular))
                        .foregroundStyle(date == 11 ? Color.white : Studio.ink)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(date == 11 ? Studio.ink : .clear))
                    HStack(spacing: 3) {
                        ForEach(0..<(date < 12 ? (date % 3) + 1 : 0), id: \.self) { i in
                            Circle().fill([Studio.mint, Studio.lilac, Studio.peach][i]).frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct TodayHero: View {
    var today: TodayData

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let hero = Studio.photo("Hero.jpg") {
                hero.resizable().scaledToFill()
                    .frame(width: 250, height: 380)
                    .clipped()
                    .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                    .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .leading, endPoint: .trailing))
                    .skeletonShape { RoundedRectangle(cornerRadius: 28, style: .continuous).padding(.leading, 40).padding(.bottom, 60) }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, -24)
                    .padding(.top, 40)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Hello,").font(.system(size: 22, weight: .light)).foregroundStyle(Studio.quiet)
                Text(today.name).font(.system(size: 44, weight: .semibold)).tracking(-1).foregroundStyle(Studio.ink)
                Text("Here's your health today.").font(.system(size: 14)).foregroundStyle(Studio.quiet)
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(today.readings, id: \.self) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.label).font(.system(size: 12)).foregroundStyle(Studio.quiet)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(r.value).font(.system(size: 30, weight: .ultraLight)).foregroundStyle(Studio.ink)
                                Text(r.unit).font(.system(size: 11)).foregroundStyle(Studio.quiet)
                            }
                        }
                    }
                }
                .padding(.top, 34)
            }
        }
        .frame(height: 420, alignment: .top)
    }
}

private struct CoachLine: View {
    var today: TodayData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next · Coach").font(.system(size: 12)).foregroundStyle(Studio.quiet)
            HStack {
                Text(today.coach).font(.system(size: 20, weight: .light)).foregroundStyle(Studio.ink)
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 14)).foregroundStyle(Studio.quiet)
            }
        }
    }
}

// MARK: - Plates

struct PlatesData: Codable, Hashable {
    struct Plate: Codable, Hashable { var name: String; var kcal: String; var photo: String }
    var upNext: String
    var energy: String
    var protein: String
    var water: String
    var plates: [Plate]
    static let sample = PlatesData(upNext: "A snack", energy: "8,888", protein: "888", water: "8.88", plates: (0..<6).map { _ in Plate(name: "A plate name", kcal: "888 kcal", photo: "") })
    static let real = PlatesData(upNext: "Edamame", energy: "2,248", protein: "134", water: "1.67", plates: [
        Plate(name: "Shakshuka", kcal: "410 kcal", photo: "plate-shakshuka.jpg"),
        Plate(name: "Salmon & greens", kcal: "620 kcal", photo: "plate-salmon.jpg"),
        Plate(name: "Quinoa bowl", kcal: "540 kcal", photo: "plate-quinoa-bowl.jpg"),
        Plate(name: "Palak paneer", kcal: "480 kcal", photo: "plate-palak-paneer.jpg"),
        Plate(name: "Steak", kcal: "690 kcal", photo: "plate-steak.jpg"),
        Plate(name: "Edamame", kcal: "190 kcal", photo: "plate-edamame.jpg"),
    ])
}

struct PlatesPage: View {
    @State private var data = DemoLoad { PlatesData.real }

    var body: some View {
        StudioPage(reload: data.reload) {
            Skeleton(data.value, sample: .sample) { PlatesHero(data: $0) }
            Skeleton(data.value, sample: .sample) { DayRings(data: $0) }
            Skeleton(data.value, sample: .sample) { PlateGrid(data: $0) }
        }
    }
}

private struct PlatesHero: View {
    var data: PlatesData

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                (Text("Fuel, ").foregroundStyle(Studio.ink) + Text("gently.").foregroundStyle(Studio.faint))
                    .font(.system(size: 34, weight: .ultraLight)).tracking(-0.8)
                Text("Up next · snack").font(.system(size: 12)).foregroundStyle(Studio.quiet).padding(.top, 14)
                Text(data.upNext).font(.system(size: 20, weight: .light)).foregroundStyle(Studio.ink)
            }
            Spacer()
            PlatePhoto(name: "plate-edamame.jpg").frame(width: 130, height: 130)
        }
    }
}

private struct PlatePhoto: View {
    var name: String
    var body: some View {
        if let photo = Studio.photo(name) {
            photo.resizable().scaledToFill().clipShape(Circle()).accessibilityHidden(true)
        } else {
            Circle().fill(Studio.rule)
        }
    }
}

private struct DayRings: View {
    var data: PlatesData

    var body: some View {
        HStack(spacing: 22) {
            ZStack {
                ring(0.88, Studio.peach, 100)
                ring(0.74, Studio.mint, 74)
                ring(0.67, Studio.sky, 48)
            }
            .frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 10) {
                stat("Energy", data.energy, "of 2,550 kcal", Studio.peach)
                stat("Protein", data.protein, "of 118 g", Studio.mint)
                stat("Water", data.water, "of 2.5 L", Studio.sky)
            }
        }
    }

    private func ring(_ value: Double, _ color: Color, _ size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 8)
            Circle().trim(from: 0, to: value).stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }

    private func stat(_ label: String, _ value: String, _ of: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).font(.system(size: 11)).foregroundStyle(Studio.quiet)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 22, weight: .light)).foregroundStyle(Studio.ink)
                Text(of).font(.system(size: 11)).foregroundStyle(Studio.quiet)
            }
        }
    }
}

private struct PlateGrid: View {
    var data: PlatesData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's plates").font(.system(size: 15, weight: .medium)).foregroundStyle(Studio.ink)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 20) {
                ForEach(data.plates, id: \.self) { plate in
                    VStack(spacing: 8) {
                        PlatePhoto(name: plate.photo).frame(width: 120, height: 120)
                        Text(plate.name).font(.system(size: 14)).foregroundStyle(Studio.ink)
                        Text(plate.kcal).font(.system(size: 11)).foregroundStyle(Studio.quiet)
                    }
                }
            }
        }
    }
}
