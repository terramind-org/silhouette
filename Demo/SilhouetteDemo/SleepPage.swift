import Silhouette
import SwiftUI

// A sleep page in a quiet, editorial style: pastel paper, hairline type and charts that read at a
// glance. Every section loads on its own and the page cascades in as one.

// MARK: - Data

struct SleepNight: Codable, Hashable {
    struct Span: Codable, Hashable { var stage: Int; var start: Double; var end: Double }
    var asleep: String
    var underGoal: String
    var bedtime: String
    var wake: String
    var spans: [Span]
    var minutes: [String]
    var shares: [String]

    static let sample = SleepNight(
        asleep: "8h 88m", underGoal: "88m under your goal", bedtime: "88:88 PM", wake: "8:88 AM",
        spans: SleepNight.real.spans, minutes: ["88m", "8h 88m", "8h 88m", "8h 88m"], shares: ["8%", "88%", "88%", "88%"]
    )
    static let real = SleepNight(
        asleep: "6h 52m", underGoal: "38m under your goal", bedtime: "11:10 PM", wake: "6:22 AM",
        spans: [
            .init(stage: 0, start: 0.00, end: 0.02), .init(stage: 2, start: 0.03, end: 0.12), .init(stage: 3, start: 0.13, end: 0.22),
            .init(stage: 2, start: 0.23, end: 0.30), .init(stage: 1, start: 0.31, end: 0.36), .init(stage: 2, start: 0.37, end: 0.46),
            .init(stage: 3, start: 0.47, end: 0.53), .init(stage: 2, start: 0.54, end: 0.62), .init(stage: 1, start: 0.63, end: 0.70),
            .init(stage: 0, start: 0.71, end: 0.72), .init(stage: 2, start: 0.73, end: 0.82), .init(stage: 1, start: 0.83, end: 0.90),
            .init(stage: 3, start: 0.91, end: 0.94), .init(stage: 1, start: 0.95, end: 0.99),
        ],
        minutes: ["20m", "1h 56m", "3h 20m", "1h 36m"], shares: ["4%", "26%", "46%", "22%"]
    )
}

struct SleepWeeks: Codable, Hashable {
    var nights: [Double]
    var average: String
    static let sample = SleepWeeks(nights: Array(repeating: 0.6, count: 14), average: "Average 8h 88m")
    static let real = SleepWeeks(nights: [0.82, 0.74, 0.9, 0.66, 0.78, 0.95, 0.7, 0.86, 0.62, 0.8, 0.88, 0.72, 0.84, 0.76], average: "Average 6h 59m")
}

struct Overnight: Codable, Hashable {
    struct Reading: Codable, Hashable { var label: String; var value: String; var unit: String; var trend: [Double]; var tone: Int }
    var readings: [Reading]
    static let sample = Overnight(readings: (0..<4).map { _ in Reading(label: "Sample label", value: "88", unit: "unit", trend: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5], tone: 0) })
    static let real = Overnight(readings: [
        Reading(label: "Readiness", value: "83", unit: "score", trend: [0.4, 0.5, 0.45, 0.6, 0.55, 0.7, 0.8], tone: 0),
        Reading(label: "Breathing", value: "14", unit: "rpm", trend: [0.5, 0.45, 0.55, 0.5, 0.4, 0.6, 0.5], tone: 1),
        Reading(label: "HRV", value: "71", unit: "ms", trend: [0.3, 0.4, 0.35, 0.5, 0.45, 0.6, 0.75], tone: 2),
        Reading(label: "Wrist temp", value: "−0.3", unit: "°C", trend: [0.5, 0.55, 0.6, 0.5, 0.7, 0.45, 0.4], tone: 3),
    ])
}

// MARK: - Look

private enum Night {
    static let ink = Color.adaptive(light: Color(red: 0.11, green: 0.11, blue: 0.14), dark: Color(white: 0.96))
    static let quiet = Color.adaptive(light: Color(red: 0.45, green: 0.44, blue: 0.52), dark: Color(white: 0.6))
    static let faint = Color.adaptive(light: Color(red: 0.68, green: 0.67, blue: 0.74), dark: Color(white: 0.38))
    static let rule = Color.adaptive(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08))
    static let stages = [
        Color(red: 0.98, green: 0.62, blue: 0.36),  // awake
        Color(red: 0.55, green: 0.78, blue: 0.98),  // REM
        Color(red: 0.45, green: 0.58, blue: 0.96),  // core
        Color(red: 0.62, green: 0.52, blue: 0.9),   // deep
    ]
    static let stageNames = ["Awake", "REM", "Core", "Deep"]
    static let tones = [Color(red: 0.45, green: 0.8, blue: 0.62), Color(red: 0.55, green: 0.78, blue: 0.98), Color(red: 0.62, green: 0.52, blue: 0.9), Color(red: 0.98, green: 0.62, blue: 0.36)]
}

private struct PaperBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        if scheme == .dark {
            Color.black
        } else {
            LinearGradient(colors: [Color(red: 0.95, green: 0.94, blue: 0.97), Color(red: 0.97, green: 0.95, blue: 0.94)], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Page

struct SleepPage: View {
    @State private var night = DemoLoad { SleepNight.real }
    @State private var weeks = DemoLoad { SleepWeeks.real }
    @State private var overnight = DemoLoad { Overnight.real }

    private func reload() { night.reload(); weeks.reload(); overnight.reload() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                Skeleton(night.value, sample: .sample) { SleepHero(night: $0) }
                Skeleton(night.value, sample: .sample) { StagesSection(night: $0) }
                Skeleton(weeks.value, sample: .sample) { NightsSection(weeks: $0) }
                Skeleton(overnight.value, sample: .sample) { OvernightSection(overnight: $0) }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 60)
            .contentShape(.rect)
            .onTapGesture(perform: reload)
        }
        .skeletonReveal(DemoReveal.current)
        .skeletonTracksScrolling()
        .background(PaperBackground().ignoresSafeArea())
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

// MARK: - Sections

private struct SleepHero: View {
    var night: SleepNight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text("Last night, ").foregroundStyle(Night.ink) + Text("restored.").foregroundStyle(Night.faint))
                .font(.system(size: 34, weight: .ultraLight))
                .tracking(-0.8)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(night.asleep).font(.system(size: 54, weight: .ultraLight)).tracking(-1.5).foregroundStyle(Night.ink)
                Text("asleep").font(.system(size: 14, weight: .light)).foregroundStyle(Night.quiet)
            }
            Text(night.underGoal).font(.system(size: 13)).foregroundStyle(Night.quiet)
            Sleeper()
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, -24)
                .padding(.top, 4)
        }
    }
}

/// The sleeper, from Halo's sleep page, fading softly into the page.
private struct Sleeper: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let photo = UIImage(named: "Sleeper.jpg") {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .brightness(scheme == .dark ? -0.18 : 0)
                .mask(EllipticalGradient(colors: [.black, .black, .clear], center: UnitPoint(x: 0.5, y: 0.52), startRadiusFraction: 0, endRadiusFraction: 0.5))
                // A photograph waits as one shape, whatever its light and dark parts.
                .skeletonShape { Ellipse().padding(.horizontal, 30).padding(.vertical, 18) }
                .accessibilityHidden(true)
        }
    }
}

/// The night, drawn: a soft moon with its glow and a scatter of stars.
private struct Moon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.78, green: 0.72, blue: 0.98).opacity(0.55), .clear], center: .center, startRadius: 40, endRadius: 104))
                .frame(width: 208, height: 208)
            // One shape, its sheen part of the fill, so it waits as one block.
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.99, green: 0.86, blue: 0.78), Color(red: 0.78, green: 0.72, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().fill(RadialGradient(colors: [Color.white.opacity(0.4), .clear], center: UnitPoint(x: 0.32, y: 0.3), startRadius: 0, endRadius: 40)))
                .compositingGroup()
                .frame(width: 128, height: 128)
            ForEach(0..<9, id: \.self) { i in
                let a = Double(i) * 0.71
                Circle().fill(Night.faint.opacity(0.7))
                    .frame(width: i % 3 == 0 ? 4 : 2.5, height: i % 3 == 0 ? 4 : 2.5)
                    .offset(x: cos(a * 4.1) * (110 + Double(i * 7)), y: sin(a * 3.3) * 78)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct StagesSection: View {
    var night: SleepNight

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stages").font(.system(size: 15, weight: .medium)).foregroundStyle(Night.ink)
            GeometryReader { proxy in
                let w = proxy.size.width - 46
                ZStack(alignment: .topLeading) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 8) {
                            Text(Night.stageNames[row]).font(.system(size: 10)).foregroundStyle(Night.faint).frame(width: 38, alignment: .leading)
                            Rectangle().fill(Night.rule).frame(height: 0.5)
                        }
                        .offset(y: CGFloat(row) * 28 + 6)
                    }
                    ForEach(night.spans, id: \.self) { span in
                        Capsule()
                            .fill(Night.stages[span.stage])
                            .frame(width: max(8, (span.end - span.start) * w), height: 12)
                            .offset(x: 46 + span.start * w, y: CGFloat(span.stage) * 28)
                    }
                }
            }
            .frame(height: 110)
            HStack {
                Text(night.bedtime)
                Spacer()
                Text(night.wake)
            }
            .font(.system(size: 11)).foregroundStyle(Night.faint)
            .padding(.leading, 46)
            HStack(alignment: .top) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Circle().fill(Night.stages[i]).frame(width: 6, height: 6)
                            Text(Night.stageNames[i]).font(.system(size: 11)).foregroundStyle(Night.quiet)
                        }
                        Text(night.minutes[i]).font(.system(size: 17, weight: .light)).foregroundStyle(Night.ink)
                        Text(night.shares[i]).font(.system(size: 11)).foregroundStyle(Night.faint)
                    }
                    if i < 3 { Spacer(minLength: 4) }
                }
            }
        }
    }
}

private struct NightsSection: View {
    var weeks: SleepWeeks

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fourteen nights").font(.system(size: 15, weight: .medium)).foregroundStyle(Night.ink)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(weeks.nights.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == weeks.nights.count - 1 ? Night.stages[3] : Night.stages[3].opacity(0.35))
                        .frame(width: 7, height: 96 * weeks.nights[i])
                    if i < weeks.nights.count - 1 { Spacer(minLength: 2) }
                }
            }
            .frame(height: 96, alignment: .bottom)
            .overlay(alignment: .top) {
                Rectangle().fill(Night.faint.opacity(0.6)).frame(height: 0.5).offset(y: 96 * 0.1)
                    .skeletonIgnored()
            }
            Text("\(weeks.average) · goal 7h 30m marked by the line").font(.system(size: 11)).foregroundStyle(Night.faint)
        }
    }
}

private struct OvernightSection: View {
    var overnight: Overnight

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Overnight").font(.system(size: 15, weight: .medium)).foregroundStyle(Night.ink)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], alignment: .leading, spacing: 22) {
                ForEach(overnight.readings, id: \.self) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Circle().fill(Night.tones[r.tone]).frame(width: 6, height: 6)
                            Text(r.label).font(.system(size: 11)).foregroundStyle(Night.quiet)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(r.value).font(.system(size: 30, weight: .ultraLight)).foregroundStyle(Night.ink)
                            Text(r.unit).font(.system(size: 11)).foregroundStyle(Night.quiet)
                        }
                        Trend(values: r.trend)
                            .stroke(Night.tones[r.tone], style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(height: 28)
                    }
                }
            }
        }
    }
}

private struct Trend: Shape {
    var values: [Double]
    func path(in rect: CGRect) -> Path {
        Path { p in
            for (i, v) in values.enumerated() {
                let pt = CGPoint(x: rect.width * Double(i) / Double(max(values.count - 1, 1)), y: rect.height * (1 - v))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }
}
