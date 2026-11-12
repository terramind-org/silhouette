import Silhouette
import SwiftUI

// Each feature shown on a screen in the style of Halo, the health app built with Silhouette.

// MARK: - Any view, with a flag (and a kept label)

struct ReadinessPage: View {
    @State private var ready = DemoLoad { true }

    var body: some View {
        StudioPage(reload: ready.reload) {
            let loading = ready.value == nil
            VStack(alignment: .leading, spacing: 14) {
                // Fixed text: shows at once, never a skeleton.
                Text("Readiness").font(.system(size: 15, weight: .medium)).foregroundStyle(Studio.ink).skeletonKeep()
                HStack(spacing: 22) {
                    ZStack {
                        Circle().inset(by: 6).stroke(Studio.mint.opacity(0.2), lineWidth: 12)
                        Circle().inset(by: 6).trim(from: 0, to: loading ? 0.88 : 0.83).stroke(Studio.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                        Text(loading ? "88" : "83").font(.system(size: 44, weight: .ultraLight)).foregroundStyle(Studio.ink)
                    }
                    .frame(width: 140, height: 140)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(loading ? "Sample state" : "Recovered").font(.system(size: 22, weight: .light)).foregroundStyle(Studio.ink)
                        Text(loading ? "A line about the night, about this long." : "HRV is above your 7-day baseline and you slept near your goal.")
                            .font(.system(size: 13)).foregroundStyle(Studio.quiet)
                    }
                }
            }
            .skeleton(isLoading: loading)
        }
    }
}

// MARK: - Your own skeleton

struct NightsChartPage: View {
    @State private var weeks = DemoLoad { SleepWeeks.real }

    var body: some View {
        StudioPage(reload: weeks.reload) {
            Text("Fourteen nights").font(.system(size: 22, weight: .light)).foregroundStyle(Studio.ink)
            Skeleton(weeks.value, sample: .sample) { weeks in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(weeks.nights.indices, id: \.self) { i in
                        Capsule().fill(i == weeks.nights.count - 1 ? Studio.lilac : Studio.lilac.opacity(0.35))
                            .frame(width: 9, height: 160 * weeks.nights[i])
                        if i < weeks.nights.count - 1 { Spacer(minLength: 2) }
                    }
                }
                .frame(height: 160, alignment: .bottom)
            }
            // Its own skeleton: fourteen bars of a typical week, rising and falling.
            .placeholder {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<14, id: \.self) { i in
                        SkeletonBox(width: .points(9), height: .points(160 * [0.7, 0.6, 0.8, 0.55, 0.75, 0.9, 0.65][i % 7]), radius: .fraction(0.5))
                        if i < 13 { Spacer(minLength: 2) }
                    }
                }
                .frame(height: 160, alignment: .bottom)
            }
        }
    }
}

// MARK: - Memory

struct PlatesMemoryPage: View {
    @State private var data = DemoLoad { PlatesData.real }

    var body: some View {
        StudioPage(reload: data.reload) {
            (Text("Fuel, ").foregroundStyle(Studio.ink) + Text("gently.").foregroundStyle(Studio.faint))
                .font(.system(size: 34, weight: .ultraLight))
            // The sample has two plates; once six have shown, the next skeleton has six.
            Skeleton(data.value, sample: PlatesData(upNext: "", energy: "", protein: "", water: "", plates: Array(PlatesData.sample.plates.prefix(2))), id: "studio.plates") { data in
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 20) {
                    ForEach(Array(data.plates.enumerated()), id: \.offset) { _, plate in
                        VStack(spacing: 8) {
                            Group {
                                if let photo = Studio.photo(plate.photo) {
                                    photo.resizable().scaledToFill().clipShape(Circle())
                                } else {
                                    Circle().fill(Studio.rule)
                                }
                            }
                            .frame(width: 120, height: 120)
                            Text(plate.name).font(.system(size: 14)).foregroundStyle(Studio.ink)
                            Text(plate.kcal).font(.system(size: 11)).foregroundStyle(Studio.quiet)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Changing size

struct CoachNoteData: Codable, Hashable {
    var text: String
    static let sample = CoachNoteData(text: "A short note from the coach.")
    static let real = CoachNoteData(text: "Readiness is solid today: your HRV sits above your 7-day baseline and you slept close to your goal. Go for 40 minutes steady in zone 2, then finish with ten minutes of mobility. Keep the hard intervals for Thursday.")
}

struct CoachNotePage: View {
    @State private var note = DemoLoad { CoachNoteData.real }

    var body: some View {
        StudioPage(reload: note.reload) {
            Text("How am I doing?").font(.system(size: 15)).foregroundStyle(Studio.ink)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Studio.rule, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .trailing)
            Skeleton(note.value, sample: .sample) { note in
                Text(note.text).font(.system(size: 17, weight: .light)).foregroundStyle(Studio.ink).lineSpacing(4)
            }
            Text("Your notes, plans and readings stay with the coach.").font(.system(size: 12)).foregroundStyle(Studio.faint)
        }
    }
}

// MARK: - AsyncSkeleton

struct CoachAnswerPage: View {
    @State private var trigger = 0

    var body: some View {
        StudioPage(reload: { trigger += 1 }) {
            Text("What should I eat tonight?").font(.system(size: 15)).foregroundStyle(Studio.ink)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Studio.rule, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .trailing)
            AsyncSkeleton(sample: PlatesData.sample.plates[0], trigger: trigger) {
                try await Task.sleep(for: .seconds(Response.current.seconds))
                return PlatesData.real.plates[1]
            } content: { plate in
                HStack(spacing: 16) {
                    Group {
                        if let photo = Studio.photo(plate.photo) { photo.resizable().scaledToFill().clipShape(Circle()) } else { Circle().fill(Studio.rule) }
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plate.name).font(.system(size: 22, weight: .light)).foregroundStyle(Studio.ink)
                        Text(plate.kcal).font(.system(size: 13)).foregroundStyle(Studio.quiet)
                        Text("Protein to finish the day, and it's quick.").font(.system(size: 13)).foregroundStyle(Studio.quiet)
                    }
                }
            }
        }
    }
}

// MARK: - ShimmerText

struct CoachThinkingPage: View {
    var body: some View {
        StudioPage(reload: {}) {
            Text("How did I sleep?").font(.system(size: 15)).foregroundStyle(Studio.ink)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Studio.rule, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .trailing)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    ForEach([Studio.mint, Studio.sky, Studio.lilac, Studio.peach], id: \.self) { Circle().fill($0).frame(width: 7, height: 7) }
                    Text("Looked at Sleep · Heart · Training").font(.system(size: 13)).foregroundStyle(Studio.quiet)
                }
                ShimmerText("Reading last night's stages…").font(.system(size: 17, weight: .light))
                ShimmerText("Comparing with your fourteen nights…").font(.system(size: 17, weight: .light))
            }
        }
    }
}
