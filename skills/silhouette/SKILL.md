---
name: silhouette
description: Use when adding loading skeletons, shimmer placeholders or loading states to a SwiftUI app with the Silhouette package, or when fixing a Silhouette skeleton that jumps, looks wrong or fires work twice. Covers choosing Skeleton, .skeleton(isLoading:) or AsyncSkeleton, sample data, hints, theming, reveals, accessibility, testing and verification.
---

# Adopting Silhouette

Silhouette draws a skeleton of a SwiftUI view by laying the real view out unseen with sample data and tracing it: a bar per line of text, a block per image, control and painted shape. When the data arrives, the content replaces the skeleton in place. Your job is to wrap the right views, give them good samples, and verify nothing moves.

Full docs: `docs/docs/index.html` in the Silhouette repo. The API's doc comments in `Sources/Silhouette/` are the source of truth.

## Install

Add the package and the product to the app target:

```swift
.package(url: "https://github.com/terramind-org/silhouette.git", from: "0.1.0")
.product(name: "Silhouette", package: "silhouette")
```

Needs iOS 17 / macOS 14 / tvOS 17 / watchOS 10 / visionOS 1. `import Silhouette` in each file that uses it. Don't add a theme or reveal unless asked; the defaults are good.

## Pick the API

| Situation | Use |
| --- | --- |
| One optional value drives a view (`User?`, `[Message]?`) | `Skeleton(data, sample:) { value in View(value) }` |
| View built from several sources, or can't be restructured | `View(...).skeleton(isLoading: flag)` with stand-in values |
| The view itself should run one async call | `AsyncSkeleton(sample:, load: { … }, content: { … })` |
| Something that can't be traced (chart, map, video) | a hint: `.skeletonBlock`, `.skeletonShape { }` |
| Work in progress, not missing content (an AI tool call) | `ShimmerText("…")` or `.shimmer(isRunning)` |

Prefer `Skeleton(data, sample:)`. Its closure only ever shows real data on screen, and it supports `id:` memory, `.empty`, `.failure` and `.placeholder`.

```swift
Skeleton(model.user, sample: .sample, id: "profile") { user in
    ProfileCard(user: user)
}
.empty(model.user?.posts.isEmpty == true) { ContentUnavailableView("No posts", systemImage: "tray") }
.failure(model.error) { RetryBanner(error: $0) }
```

`.empty` and `.failure` are methods on `Skeleton`: chain them directly after it, before other modifiers.

## Samples

- Add `static let sample` (or `static let samples` for arrays) on the model type, next to its definition.
- Use **typical lengths**: a usual name, a bio that wraps to the usual number of lines, the usual count of list items (3 to 6). The skeleton takes exactly the sample's space; a short sample means the page grows on reveal.
- Arrays used in `ForEach`/`List` need distinct ids in their samples.
- Don't show sample values anywhere else. Only real data reaches the closure on screen; the sample is only ever traced.
- No sample yet? Run once in debug: Silhouette logs a sample to paste (subsystem `Silhouette`) with your type's shape and every value replaced.
- With `.skeleton(isLoading:)`, stand in for missing values with strings of typical length: `Text(user?.name ?? "Placeholder name")`.

## Hints

| Hint | When |
| --- | --- |
| `.skeletonBlock(cornerRadius:)` | Charts, `Map`, video, web views, rows of tiny icons: one solid block. System-drawn views (maps, web, video) always need this. |
| `.skeletonIgnored()` | Badges, dividers, decorations; and **any container background that isn't the page colour**. The view keeps its space. |
| `.skeletonShape { Circle() }` | A specific outline, e.g. round avatars, a chart's bars built from `SkeletonBox`. |
| `.placeholder { }` on `Skeleton` | Replace the whole traced shape. Keep passing a sample: the region still sizes from the content. |
| `SkeletonBox(width:height:radius:)` | Standalone placeholder shapes; lengths are points, `.fraction(_:)` or `.em(_:)`. |

Container backgrounds: surfaces in the page colour (white card on a white page, black on black) are skipped automatically. Any other fill traces as one solid block, so put `.skeletonIgnored()` on the background view itself:

```swift
content
    .padding()
    .background {
        RoundedRectangle(cornerRadius: 20).fill(.cardBackground).skeletonIgnored()
    }
```

## Side effects

Silhouette lays out a second, tracing copy of the content. Any `.task` or `.onAppear` inside the skeleton runs for that copy too. Either start work outside the skeleton (preferred), or guard it:

```swift
@Environment(\.isDrawingSkeleton) private var isDrawingSkeleton
// …
.task { guard !isDrawingSkeleton else { return }; await model.loadComments() }
```

Same for analytics, timers and anything that writes state.

## Images

- Remote images: `SkeletonAsyncImage(url:) { $0.resizable().scaledToFill() }`. It never holds back a reveal, shimmers until loaded, and the tracing copy never downloads.
- **Always give images a frame or an aspect ratio.** An image has no size until it loads; without one its skeleton is empty and the page jumps.

## Lists

Put the skeleton on each row, not around a `List` or `LazyVStack`:

```swift
List(model.messages ?? Message.samples) { message in
    MessageRow(message: message)
        .skeleton(isLoading: model.messages == nil)
}
```

## Data fetching

- Keep the value optional in the model; load from `.task` on the screen, outside the skeleton.
- Refetch: pass nothing and the old content stays until replaced; pass `isLoading: model.isRefreshing` to go back to a skeleton drawn from what's on screen.
- Add `.skeletonTracksScrolling()` to scroll views that host skeletons, so content landing mid-scroll appears at once (iOS 18+, no-op earlier).
- `id:` makes the next skeleton exact (in-memory within a launch; for `Codable` data, a scrubbed layout in `UserDefaults` across launches). Call `forgetSkeletonShapes()` on sign-out whenever you use `id:`.

## Theming and reveals

Only if asked. Set once near the root; scope changes with the closure form.

```swift
ContentView()
    .skeletonTheme(SkeletonTheme(radius: .pill))      // or .skeletonTheme { $0.speed = .fast }
    .skeletonReveal(.smart)                            // default
```

- Theme fields: `light`/`dark` `SkeletonColors(base:highlight:)` (or `.tinted(color)`), `animation` (`.shimmer`, `.groupShimmer`, `.pulse`, `.none`), `speed` (`.slow` default), `direction`, `bandWidth`, `radius` (`.auto`, `.points`, `.pill`), `text`, `colorScheme`.
- Text bars default to cap height → descender. If lines merge in a dense list: `.skeletonText(SkeletonTextMetrics(top: .xHeight, bottom: .baseline))`.
- Reveals: `.smart` (default), `.together`, `.sequence`, `.sweep`, `.instant`. Custom: start from one and change `order` (`.together`, `.byPosition`, `.byRow`, `.custom { piece in delay }`), `enter` (`.blur`, `.rise`, `.zoom`), `wipe`, `delay`, `duration` (per piece, 0.2 s), `hold`, `choose`. Times cap at 1 s; Reduce Motion makes every reveal instant.

## Accessibility

- Pass `label: Text("Loading profile")` to every `Skeleton`, `.skeleton` and `AsyncSkeleton` that covers a meaningful region. The loading region is one VoiceOver element reading that label.
- Use `onReveal:` to move focus (`@AccessibilityFocusState`) when the loaded content is the point of the screen.
- Nothing else to do: skeletons are hidden from VoiceOver and hit testing, follow Dynamic Type, RTL and Reduce Motion.

## Testing

- UI tests: wait for real content (`app.staticTexts["Ada"].waitForExistence(timeout:)`); the sample is never exposed to accessibility.
- Speed up UI tests with `.skeletonReveal(.instant)` behind a launch argument.
- Snapshot tests of loading states: `.skeletonTheme { $0.animation = .none }` so the wall-clock shimmer doesn't vary.

## Verify with the debug overlay

Turn it on while adopting: `.skeletonDebug(.outlines)` on the root, `setSkeletonDebug(.all)`, or the launch argument `-SilhouetteDebug YES` (`xray` adds x-ray). Remove code-based debug calls before finishing.

- Blue outline while loading, tagged with the shape's source (`sample`, `last shown`, `remembered`, `on screen`, `custom`, `content`, `fallback`).
- After reveal: **green "no move"** is the goal; **red "moved ±Npt"** means the sample's lengths are off. Fix the sample, not the layout.
- `fallback` means nothing to measure: add a sample or an id.
- Console (debug builds) also logs missing samples, moves, and zero-size skeletons.

## Pitfalls

- Wrapping a whole screen or `List` in one skeleton. Wrap the regions that load.
- Samples with one-word strings or empty arrays: the page jumps on reveal.
- Coloured card backgrounds without `.skeletonIgnored()`: the card becomes a slab.
- Work in `.task`/`.onAppear` inside the content without the `isDrawingSkeleton` guard: duplicate requests.
- Unsized images, or `Spacer`-only views while loading: nothing to draw.
- Adding `.skeletonIgnored()` to the card instead of its background view: the whole card disappears from the skeleton.
- Using `id:` without `forgetSkeletonShapes()` on sign-out.
- Expecting `AsyncSkeleton` to take a custom error view: it shows `localizedDescription`. Use `Skeleton` + `.failure` for your own.
- Text bars look like plain redaction on iOS 17 / macOS 14: expected; glyph-exact bars need iOS 18+.

## Checklist

- [ ] Each loading region is wrapped at the smallest sensible level, rows rather than lists.
- [ ] Every `Skeleton` has a `sample` with typical lengths, defined as `static let` on the model.
- [ ] Coloured container backgrounds use `.skeletonIgnored()` on the background view.
- [ ] Charts, maps and system views use `.skeletonBlock` or `.skeletonShape`.
- [ ] Every image has a frame or aspect ratio; remote images use `SkeletonAsyncImage`.
- [ ] No `.task`/`.onAppear` inside skeleton content runs unguarded.
- [ ] Meaningful regions pass `label:`.
- [ ] Scroll views hosting skeletons have `.skeletonTracksScrolling()`.
- [ ] `forgetSkeletonShapes()` is called on sign-out if any `id:` is used.
- [ ] With the debug overlay on, every region reveals green "no move" in light and dark, at a large Dynamic Type size too.
- [ ] Debug overlay code removed; the project builds.
