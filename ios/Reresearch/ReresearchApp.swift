import SwiftUI
import UIKit

@main
struct ReresearchApp: App {
    @State private var store = ReaderStore()
    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("--brand-study") { BrandStudyView() }
                else if ProcessInfo.processInfo.arguments.contains("--post-study") { PostStudyView() }
                else { RootView() }
            }
                .environment(store)
                .font(Design.font(14))
                .foregroundStyle(Design.foreground)
                .tint(Design.accent)
                .preferredColorScheme(.light)
        }
    }
}

enum Destination: Hashable { case thread(String), settings, privacy }

struct RootView: View {
    @Environment(ReaderStore.self) private var store
    @State private var path: [Destination] = []
    @State private var mainTab: MainTab = .feed
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.signedIn { MainShell(selection: $mainTab) }
                else { LoginView() }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .thread(let id):
                    if let paper = store.papers.first(where: { $0.id == id }) { ThreadView(paper: paper) }
                case .settings: SettingsView()
                case .privacy: PrivacyView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: store.signedIn) { _, _ in path = [] }
        }
        .background(Design.background)
        .environment(\.returnToFeed, { mainTab = .feed; path = [] })
        .environment(\.selectMainTab, { mainTab = $0; path = [] })
        .environment(\.openPrivacy, { path.append(.privacy) })
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                Text(toast).font(Design.font(13, .medium)).padding(.horizontal, 16).padding(.vertical, 11)
                    .foregroundStyle(Design.background).background(Design.foreground, in: Capsule())
                    .padding(.horizontal, 16).padding(.bottom, path.isEmpty && store.signedIn ? 100 : 16).allowsHitTesting(false).transition(.opacity)
            }
        }
    }
}

private struct ReturnToFeedKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
private struct SelectMainTabKey: EnvironmentKey { static let defaultValue: (MainTab) -> Void = { _ in } }
private struct OpenPrivacyKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var returnToFeed: () -> Void {
        get { self[ReturnToFeedKey.self] }
        set { self[ReturnToFeedKey.self] = newValue }
    }
    var selectMainTab: (MainTab) -> Void {
        get { self[SelectMainTabKey.self] }
        set { self[SelectMainTabKey.self] = newValue }
    }
    var openPrivacy: () -> Void {
        get { self[OpenPrivacyKey.self] }
        set { self[OpenPrivacyKey.self] = newValue }
    }
}

#Preview { RootView().environment(ReaderStore(persist: false)) }

enum MainTab: String, CaseIterable {
    case feed = "Feed", saved = "Saved", queue = "Queue", settings = "Settings"
    var symbol: String {
        switch self {
        case .feed: "house"
        case .saved: "bookmark"
        case .queue: "square.stack"
        case .settings: "person"
        }
    }
    var selectedSymbol: String { symbol + ".fill" }
}

struct MainShell: View {
    @Environment(ReaderStore.self) private var store
    @Binding var selection: MainTab
    @State private var menuProgress: CGFloat = 0
    @State private var menuInteraction: MenuInteraction = .idle
    @State private var menuAnimationRevision = 0
    @State private var searchPresented = false
    @State private var launchProgress = 0.0
    @State private var launchFinished = false
    @State private var launchStarted = false
    @State private var chrome = ReaderChromeMotion()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let navigationInset: CGFloat = 24
    private enum MenuInteraction: Equatable { case idle, dragging(origin: CGFloat), settling }
    private var pageInteractive: Bool { launchFinished && menuProgress == 0 && menuInteraction == .idle }
    private var menuInteractive: Bool { launchFinished && menuProgress == 1 && menuInteraction == .idle }
    private var topChromeHeight: CGFloat { 56 + (selection == .feed ? 52 : selection == .settings ? 0 : 44) }
    var body: some View {
        GeometryReader { geometry in
            let top = geometry.safeAreaInsets.top
            let height = geometry.size.height + top + geometry.safeAreaInsets.bottom
            let reveal = min(geometry.size.width * 0.78, 320)
            ZStack(alignment: .topLeading) {
                Design.background
                AppMenu { setMenuOpen(false) }
                    .padding(.top, top + 20)
                    .frame(width: reveal, height: height, alignment: .topLeading)
                    .allowsHitTesting(menuInteractive).accessibilityHidden(!menuInteractive)
                BrandArrival(progress: launchProgress, isComplete: launchFinished,
                             size: CGSize(width: geometry.size.width, height: height),
                             safeTop: top, motion: store.brand,
                             chrome: chrome) {
                    mainPage
                    .allowsHitTesting(pageInteractive)
                    .padding(.top, top)
                    .frame(width: geometry.size.width, height: height)
                    .background(Design.background)
                    .overlay(alignment: .bottom) {
                        FloatingNavigation(selection: $selection)
                            .padding([.horizontal, .bottom], navigationInset)
                            .allowsHitTesting(pageInteractive).accessibilityHidden(!pageInteractive)
                            .modifier(ReaderTrayTranslation(chrome: chrome))
                    }
                    .overlay {
                        Button { setMenuOpen(false) } label: {
                            Rectangle().fill(.white.opacity(0.001)).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).accessibilityLabel("Close menu")
                        .opacity(menuProgress > 0 ? 1 : 0)
                        .allowsHitTesting(menuInteractive).accessibilityHidden(!menuInteractive)
                    }
                }
                    .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 56, style: .continuous)
                            .strokeBorder(Color(white: 0.91), lineWidth: 1)
                            .opacity(menuProgress).allowsHitTesting(false)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 56, style: .continuous)
                            .fill(Design.background)
                            .shadow(color: .black.opacity(0.09 * menuProgress), radius: 24, x: -6, y: 10)
                            .shadow(color: .black.opacity(0.055 * menuProgress), radius: 5, x: -2, y: 2)
                    }
                    .offset(x: reveal * menuProgress)
            }
            .frame(width: geometry.size.width, height: height)
            .offset(y: -top)
            .gesture(MenuPanGesture(canBegin: launchFinished && menuInteraction != .settling,
                                    excludes: { point in
                                        selection == .feed && menuProgress == 0 && chrome.horizontalContentFrame.contains(point)
                                    }) { phase, translation, velocity in
                switch phase {
                case .began:
                    revealChrome()
                    menuAnimationRevision += 1
                    menuInteraction = .dragging(origin: menuProgress)
                case .changed:
                    guard case .dragging(let origin) = menuInteraction else { return }
                    menuProgress = min(1, max(0, origin + translation / reveal))
                case .ended:
                    guard case .dragging(let origin) = menuInteraction else { return }
                    let projected = origin + (translation + velocity * 0.18) / reveal
                    setMenuOpen(projected > 0.5)
                case .cancelled, .failed:
                    guard case .dragging = menuInteraction else { return }
                    setMenuOpen(menuProgress > 0.5)
                default: break
                }
            })
        }
        .background(Design.background)
        .task {
            guard !launchStarted else { return }
            launchStarted = true
            let shouldPlay = !store.didPresentLaunch
            store.didPresentLaunch = true
            store.brand.rest(as: .orb)
            if !shouldPlay || reduceMotion || ProcessInfo.processInfo.arguments.contains("--skip-intro") {
                launchProgress = 1
                launchFinished = true
                return
            }
            do { try await Task.sleep(for: .seconds(0.65)) }
            catch { return }
            withAnimation(.linear(duration: 2.9), completionCriteria: .removed) {
                launchProgress = 1
            } completion: {
                launchFinished = true
            }
        }
        .sheet(isPresented: $searchPresented) {
            PaperSearchView().presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .accessibilityAction(.escape) { setMenuOpen(false) }
        .sensoryFeedback(.success, trigger: store.brand.refreshCompletions)
        .onChange(of: selection) { _, value in
            revealChrome()
            if value == .settings { store.brand.selectPalette(.all) }
        }
        .onChange(of: store.isFetching) { _, fetching in if fetching { revealChrome() } }
    }
    private func revealChrome() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { chrome.reveal() }
    }
    private func handleFeedScroll(_ old: FeedScrollSample, _ new: FeedScrollSample) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            chrome.observe(position: new.offset, maximum: new.maximumOffset,
                           height: topChromeHeight,
                           enabled: launchFinished && menuProgress == 0 && !store.isFetching
                                    && abs(new.maximumOffset - old.maximumOffset) < 1,
                           viewportHeight: new.viewportHeight, contentHeight: new.contentHeight)
        }
    }
    private func setMenuOpen(_ open: Bool) {
        menuAnimationRevision += 1
        let revision = menuAnimationRevision
        if reduceMotion {
            menuProgress = open ? 1 : 0
            menuInteraction = .idle
            return
        }
        menuInteraction = .settling
        withAnimation(.spring(response: 0.34, dampingFraction: 1), completionCriteria: .removed) {
            menuProgress = open ? 1 : 0
        } completion: {
            if revision == menuAnimationRevision { menuInteraction = .idle }
        }
    }
    private var mainPage: some View {
        ZStack(alignment: .top) {
            if selection == .settings { SettingsView(showHeader: false).padding(.top, 56) }
            else {
                FeedView(mode: selection, chrome: chrome, onScrollChange: handleFeedScroll).id(selection)
            }
            HStack {
                Button { setMenuOpen(true) } label: { MenuGlyph().frame(width: 24, height: 24).frame(width: 44, height: 48) }.accessibilityLabel("Menu")
                Spacer()
                Button { searchPresented = true } label: { Image(systemName: "magnifyingglass").font(.system(size: 21, weight: .regular)).frame(width: 44, height: 48) }.accessibilityLabel("Search")
            }
            .foregroundStyle(Design.foreground)
            .padding(.horizontal, Design.pageInset - 12).frame(height: 56)
            .background(Design.background)
            .modifier(ReaderHeaderTranslation(chrome: chrome))
        }
        .accessibilityHidden(!pageInteractive)
    }
}

// A horizontal pan must win over paper links, while vertical pans remain
// available to the feed. Window coordinates stay stable as the page moves.
private struct MenuPanGesture: UIGestureRecognizerRepresentable {
    var canBegin: Bool
    var excludes: (CGPoint) -> Bool = { _ in false }
    var action: (UIGestureRecognizer.State, CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        context.coordinator.canBegin = canBegin
        context.coordinator.excludes = excludes
        pan.delegate = context.coordinator
        return pan
    }
    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.canBegin = canBegin
        context.coordinator.excludes = excludes
    }
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let window = recognizer.view?.window
        action(recognizer.state, recognizer.translation(in: window).x, recognizer.velocity(in: window).x)
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var canBegin = true
        var excludes: (CGPoint) -> Bool = { _ in false }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if excludes(touch.location(in: touch.view?.window)) { return false }
            // Horizontal content, such as the topic strip, owns its swipe.
            var ancestor = touch.view
            while let view = ancestor {
                if let scroll = view as? UIScrollView,
                   scroll.isScrollEnabled && scroll.contentSize.width > scroll.bounds.width + 1 {
                    return false
                }
                ancestor = view.superview
            }
            return true
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard canBegin, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view?.window)
            return abs(velocity.x) > abs(velocity.y) * 1.3
        }
    }
}

private struct MenuGlyph: View {
    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: CGPoint(x: 3, y: 8)); path.addLine(to: CGPoint(x: 21, y: 8))
            path.move(to: CGPoint(x: 3, y: 16)); path.addLine(to: CGPoint(x: 15, y: 16))
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

struct FloatingNavigation: View {
    @Binding var selection: MainTab
    @Namespace private var selectionAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if #available(iOS 26.0, *) {
            buttons.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            buttons.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 14, y: 5)
        }
    }
    private var buttons: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.84)) { selection = tab }
                } label: {
                    trayIcon(tab, selected: selection == tab)
                        .foregroundStyle(Design.foreground)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background {
                            if selection == tab { selectionSurface.matchedGeometryEffect(id: "selection", in: selectionAnimation) }
                        }.contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }.padding(4).frame(height: 64)
    }
    @ViewBuilder private func trayIcon(_ tab: MainTab, selected: Bool) -> some View {
        // Optical sizes vary by silhouette; every outline uses the same
        // point-based stroke, independent of its drawing dimensions.
        Group {
            switch tab {
            case .feed:
                MinimalTrayIcon(kind: .home, selected: selected)
                    .frame(width: 27, height: 27).offset(y: -0.35)
            case .saved:
                MinimalTrayIcon(kind: .bookmark, selected: selected)
                    .frame(width: 28, height: 28)
            case .queue:
                MinimalTrayIcon(kind: .queue, selected: selected)
                    .frame(width: 28, height: 28)
            case .settings:
                MinimalTrayIcon(kind: .person, selected: selected)
                    .frame(width: 28, height: 26)
            }
        }
        .frame(width: 32, height: 32)
    }
    private var selectionSurface: some View {
        Capsule().fill(.regularMaterial)
            .overlay { Capsule().fill(.black.opacity(0.085)) }
    }
}

private struct MinimalTrayIcon: View {
    enum Kind { case home, bookmark, queue, person }
    var kind: Kind
    var selected: Bool
    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 24
            let scaleY = size.height / 24
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scaleX, y: y * scaleY) }
            let stroke = StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round)
            switch kind {
            case .home:
                var house = Path()
                house.move(to: point(10.25, 3.65))
                house.addCurve(to: point(13.75, 3.65), control1: point(11.3, 2.75), control2: point(12.7, 2.75))
                house.addLine(to: point(19.75, 8.8))
                house.addCurve(to: point(21, 11.55), control1: point(20.6, 9.5), control2: point(21, 10.4))
                house.addLine(to: point(21, 18))
                house.addCurve(to: point(17.5, 21.5), control1: point(21, 20.2), control2: point(19.7, 21.5))
                house.addLine(to: point(6.5, 21.5))
                house.addCurve(to: point(3, 18), control1: point(4.3, 21.5), control2: point(3, 20.2))
                house.addLine(to: point(3, 11.55))
                house.addCurve(to: point(4.25, 8.8), control1: point(3, 10.4), control2: point(3.4, 9.5))
                house.closeSubpath()
                if selected { context.fill(house, with: .foreground) }
                context.stroke(house, with: .foreground, style: stroke)
            case .bookmark:
                var bookmark = Path()
                bookmark.move(to: point(6.5, 2.5))
                bookmark.addLine(to: point(17.5, 2.5))
                bookmark.addQuadCurve(to: point(19, 4), control: point(19, 2.5))
                bookmark.addLine(to: point(19, 21.5))
                bookmark.addLine(to: point(12, 17))
                bookmark.addLine(to: point(5, 21.5))
                bookmark.addLine(to: point(5, 4))
                bookmark.addQuadCurve(to: point(6.5, 2.5), control: point(5, 2.5))
                bookmark.closeSubpath()
                if selected { context.fill(bookmark, with: .foreground) }
                context.stroke(bookmark, with: .foreground, style: stroke)
            case .queue:
                var stack = Path()
                stack.move(to: point(8, 1.5)); stack.addLine(to: point(16, 1.5))
                stack.move(to: point(6, 4.5)); stack.addLine(to: point(18, 4.5))
                context.stroke(stack, with: .foreground, style: stroke)
                let front = Path(roundedRect: CGRect(x: 4 * scaleX, y: 7.5 * scaleY, width: 16 * scaleX, height: 14.5 * scaleY), cornerRadius: 2 * scaleX)
                if selected { context.fill(front, with: .foreground) }
                context.stroke(front, with: .foreground, style: stroke)
            case .person:
                let headDiameter = 7 * min(scaleX, scaleY)
                let head = Path(ellipseIn: CGRect(x: 12 * scaleX - headDiameter / 2, y: 6 * scaleY - headDiameter / 2, width: headDiameter, height: headDiameter))
                var shoulders = Path()
                shoulders.move(to: point(3.5, 20))
                shoulders.addCurve(to: point(12, 14), control1: point(4, 16.7), control2: point(7.5, 14))
                shoulders.addCurve(to: point(20.5, 20), control1: point(16.5, 14), control2: point(20, 16.7))
                shoulders.addQuadCurve(to: point(19, 21.5), control: point(20.65, 21.5))
                shoulders.addLine(to: point(5, 21.5))
                shoulders.addQuadCurve(to: point(3.5, 20), control: point(3.35, 21.5))
                shoulders.closeSubpath()
                if selected {
                    context.fill(head, with: .foreground); context.fill(shoulders, with: .foreground)
                }
                // Retain the same stroke in both states so filling does not shrink
                // the silhouette or drop its rounded lower corners.
                context.stroke(head, with: .foreground, style: stroke)
                context.stroke(shoulders, with: .foreground, style: stroke)
            }
        }.accessibilityHidden(true)
    }
}

private struct AppMenu: View {
    let close: () -> Void
    @Environment(ReaderStore.self) private var store
    @Environment(\.selectMainTab) private var selectTab
    @Environment(\.openPrivacy) private var openPrivacy
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            BrandLogo(size: 48).padding(.bottom, 6)
            Button { close(); Task { await store.fetch() } } label: { Label("Fetch new papers", systemImage: "arrow.clockwise") }
            Button { close(); selectTab(.settings) } label: { Label("Reading preferences", systemImage: "slider.horizontal.3") }
            Button { close(); openPrivacy() } label: { Label("Privacy", systemImage: "hand.raised") }
            Button { close(); store.signedIn = false } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
        }.font(Design.font(16)).foregroundStyle(Design.foreground)
            .buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading).padding(28)
    }
}

private struct PaperSearchView: View {
    @Environment(ReaderStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool
    private var results: [Paper] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return store.papers.filter { [$0.title, $0.headline ?? "", $0.authors.joined(separator: " "), $0.tags.joined(separator: " ")].joined(separator: " ").localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Design.muted)
                        TextField("Search papers", text: $query).font(Design.font(16)).focused($focused).submitLabel(.search).autocorrectionDisabled()
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Design.muted) }.accessibilityLabel("Clear search") }
                    }.padding(12).background(Design.raised, in: RoundedRectangle(cornerRadius: 14))
                    Button("Cancel") { dismiss() }.font(Design.font(14))
                }.padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 16)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { paper in
                            if paper.queued == true && !store.completed.contains(paper.id) { QueueRow(paper: paper) }
                            else { PaperCard(paper: paper) }
                        }
                        if !query.isEmpty && results.isEmpty { Text("No papers found.").font(Design.font(14)).foregroundStyle(Design.muted).padding(40) }
                    }
                }.scrollDismissesKeyboard(.interactively)
            }.background(Design.background)
                .navigationDestination(for: Destination.self) { destination in
                    if case .thread(let id) = destination, let paper = store.papers.first(where: { $0.id == id }) { ThreadView(paper: paper) }
                }
                .toolbar(.hidden, for: .navigationBar)
                .onAppear { focused = true }
        }
    }
}
