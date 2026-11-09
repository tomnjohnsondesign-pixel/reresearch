import SwiftUI
import Observation

/// Shared motion vocabulary. The renderer stays the same across every surface.
@MainActor @Observable
final class BrandMotion {
    enum Expression: String, CaseIterable { case orb, ring, ripple, loading }
    private(set) var expression: Expression = .orb
    private(set) var surgeStarted = -100.0
    private(set) var refreshStarted = -100.0
    private(set) var isRefreshing = false
    private(set) var refreshCompletions = 0
    private var activeJobs = 0
    private var restingExpression: Expression = .orb
    var pullAmount = 0.0
    private(set) var palette: BrandPalette = .all
    private(set) var paletteChangedAt = -100.0
    private(set) var colourFlow = BrandColourFlow()
    let epoch = Date.now.timeIntervalSinceReferenceDate
    var working: Bool { activeJobs > 0 }

    var focus: Double { expression == .orb && !working ? 1 : 0 }
    var energy: Double { working || expression == .loading ? 1 : 0 }
    var elapsed: Double { Date.now.timeIntervalSinceReferenceDate - epoch }
    var accessibilityStatus: String {
        if isRefreshing { return "Refreshing" }
        if pullAmount >= 1 { return "Release to refresh" }
        if pullAmount > 0 { return "Pull to refresh" }
        return working ? "Loading" : "Ready"
    }

    func express(_ value: Expression) {
        expression = value
        if value == .ripple { surgeStarted = elapsed }
    }
    func selectPalette(_ value: BrandPalette) {
        guard value != palette else { return }
        // Rapid category changes recolour the existing gesture; never jump
        // back to its opening pose or queue several flourishes.
        let now = elapsed
        if now - paletteChangedAt >= 1.8 { paletteChangedAt = now }
        colourFlow.select(value.pigments, at: now)
        palette = value
    }
    func next() {
        let values = Expression.allCases
        express(values[(values.firstIndex(of: expression)! + 1) % values.count])
    }
    func beginRefresh() {
        beginWork()
        refreshStarted = elapsed
        isRefreshing = true
        pullAmount = 0
    }
    func endRefresh(completed: Bool) {
        endWork()
        isRefreshing = false
        expression = restingExpression
        if completed { refreshCompletions += 1 }
    }
    func rest(as value: Expression) { restingExpression = value; express(value) }
    func beginWork() { activeJobs += 1 }
    func endWork() { activeJobs = max(0, activeJobs - 1) }
}

struct BrandLogo: View {
    @Environment(ReaderStore.self) private var store
    var size: CGFloat = 44
    var body: some View {
        BrandMark(motion: store.brand)
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore).accessibilityLabel("Research brand mark")
            .accessibilityValue(store.brand.accessibilityStatus)
    }
}

struct BrandMark: View {
    let motion: BrandMotion
    var focusOverride: Double? = nil
    var compactAmount: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        BrandField(
            epoch: motion.epoch,
            focus: focusOverride ?? max(0, motion.focus - motion.pullAmount * 1.4),
            energy: motion.energy,
            surgeStarted: motion.surgeStarted,
            refreshStarted: motion.refreshStarted,
            refreshActivity: reduceMotion ? 0 : motion.isRefreshing ? 1 : 0,
            compactAmount: compactAmount,
            colourFlow: reduceMotion || focusOverride != nil
                ? BrandColourFlow.settled(motion.palette.pigments) : motion.colourFlow.shaderValues,
            paletteChangedAt: reduceMotion || focusOverride != nil ? -100 : motion.paletteChangedAt,
            pull: motion.pullAmount,
            frozen: reduceMotion || scenePhase != .active
        )
        .animation(reduceMotion || focusOverride != nil ? nil : .smooth(duration: motion.isRefreshing ? 0.95 : 1.35), value: motion.focus)
        .animation(reduceMotion ? nil : .smooth(duration: 1.2), value: motion.energy)
        .animation(reduceMotion || motion.pullAmount > 0 ? nil : .smooth(duration: 0.65), value: motion.pullAmount)
        .animation(reduceMotion ? nil : .smooth(duration: motion.isRefreshing ? 1.9 : 2.0), value: motion.isRefreshing)
        .allowsHitTesting(false)
    }
}

/// One persistent mark travels from the opening scene into the live header.
/// A single progress value choreographs position, scale, focus and clearing fog.
struct BrandArrival<Content: View>: View, Animatable {
    var progress: Double
    let isComplete: Bool
    let size: CGSize
    let safeTop: CGFloat
    let motion: BrandMotion
    let content: Content
    let chrome: ReaderChromeMotion?

    init(progress: Double, isComplete: Bool, size: CGSize, safeTop: CGFloat,
         motion: BrandMotion, chrome: ReaderChromeMotion? = nil,
         @ViewBuilder content: () -> Content) {
        self.progress = progress; self.isComplete = isComplete
        self.size = size; self.safeTop = safeTop; self.motion = motion
        self.content = content()
        self.chrome = chrome
    }
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    private func ease(_ start: Double, _ end: Double) -> Double {
        let t = min(1, max(0, (progress - start) / (end - start)))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    var body: some View {
        let chromeDistance = isComplete ? chrome?.distance ?? 0 : 0
        let chromeProgress = isComplete ? chrome?.progress ?? 0 : 0
        let travel = ease(0.04, 0.9)
        let reveal = ease(0.18, 0.94)
        let largeSize = min(size.width - 40, 440)
        let markSize = largeSize * pow(50 / largeSize, travel)
        let markY = size.height * 0.5 + (safeTop + 28 - size.height * 0.5) * travel
        ZStack(alignment: .topLeading) {
            content.opacity(reveal)
            if !isComplete {
                Rectangle().fill(.regularMaterial)
                    .overlay { Color.white.opacity(1 - reveal) }
                    .opacity(1 - reveal)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            BrandMark(motion: motion, focusOverride: isComplete ? nil : 1, compactAmount: travel)
                .frame(width: markSize, height: markSize)
                .position(x: size.width * 0.5, y: markY - chromeDistance * travel)
                .accessibilityElement(children: .ignore).accessibilityLabel("Research brand mark")
                .accessibilityValue(motion.accessibilityStatus)
                .accessibilityHidden(chromeProgress > 0.5)
            // The departing header passes behind the system status area;
            // articles always remain below it in the changing layout.
            Color.white.frame(height: safeTop)
                .opacity(min(1, chromeProgress * 3))
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Focus and energy interpolate at the renderer, preserving all ten orb identities.
private struct BrandField: View, Animatable {
    var epoch: Double
    var focus: Double
    var energy: Double
    var surgeStarted: Double
    var refreshStarted: Double
    var refreshActivity: Double
    var compactAmount: Double
    var colourFlow: [Float]
    var paletteChangedAt: Double
    var pull: Double
    var frozen: Bool
    typealias MotionValues = AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<AnimatablePair<Double, Double>, Double>>
    var animatableData: MotionValues {
        get { AnimatablePair(AnimatablePair(focus, energy), AnimatablePair(AnimatablePair(pull, refreshActivity), compactAmount)) }
        set {
            let motion = newValue
            focus = motion.first.first; energy = motion.first.second
            pull = motion.second.first.first; refreshActivity = motion.second.first.second
            compactAmount = motion.second.second
        }
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: frozen)) { timeline in
            let time = frozen ? 0 : timeline.date.timeIntervalSinceReferenceDate - epoch
            GeometryReader { geometry in
                // Enough room for the entire visible pigment tail without
                // shading a needlessly large offscreen surface every frame.
                let padding = max(36, min(geometry.size.width, geometry.size.height) * 0.18)
                Rectangle().fill(.white)
                    .frame(width: geometry.size.width + padding * 2, height: geometry.size.height + padding * 2)
                    .colorEffect(ShaderLibrary.brandField(
                        .float2(Float(geometry.size.width), Float(geometry.size.height)),
                        .float(Float(padding)),
                        .float(Float(time)), .float(Float(focus)), .float(Float(energy)),
                        .float(frozen ? -100 : Float(surgeStarted)), .float(Float(pull)),
                        .float(Float(refreshStarted)), .float(Float(refreshActivity)),
                        .float(Float(compactAmount)),
                        .floatArray(colourFlow),
                        .float(Float(paletteChangedAt))
                    ))
                    .offset(x: -padding, y: -padding)
            }
        }
    }
}

/// An isolated design canvas, never inserted into the product navigation.
struct BrandStudyView: View {
    @State private var motion = BrandMotion()
    var body: some View {
        GeometryReader { geometry in
            Button { motion.next() } label: {
                ZStack {
                    Rectangle().fill(.white)
                    BrandMark(motion: motion)
                }
                .frame(width: min(geometry.size.width - 40, 440), height: min(geometry.size.width - 40, 440))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Explore brand motion")
            .accessibilityValue(motion.expression.rawValue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .highPriorityGesture(DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.height > 50 {
                    motion.express(.ripple)
                }
            })
        }
        .background(.white)
    }
}

#Preview("Brand motion — tap to explore") { BrandStudyView() }
