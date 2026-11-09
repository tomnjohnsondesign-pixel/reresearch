import SwiftUI

@main
struct ReresearchApp: App {
    @State private var store = ReaderStore()
    var body: some Scene {
        WindowGroup {
            RootView()
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
    @Binding var selection: MainTab
    @State private var feedSort: FeedTab = .foryou
    @State private var sheet: ShellSheet?
    private let navigationInset: CGFloat = 20
    private enum ShellSheet: String, Identifiable { case menu, search; var id: String { rawValue } }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { sheet = .menu } label: { MenuGlyph().frame(width: 24, height: 24).frame(width: 44, height: 48) }.accessibilityLabel("Menu")
                Spacer()
                Button { sheet = .search } label: { Image(systemName: "magnifyingglass").font(.system(size: 24, weight: .regular)).frame(width: 44, height: 48) }.accessibilityLabel("Search")
            }
            .overlay { Wordmark(size: 23).allowsHitTesting(false) }
            .foregroundStyle(Design.foreground)
            .padding(.horizontal, 12).frame(height: 56)
            if selection == .settings { SettingsView(showHeader: false) }
            else { FeedView(mode: selection, feedSort: $feedSort).id(selection) }
        }
        .background(Design.background)
        .overlay(alignment: .bottom) {
            FloatingNavigation(selection: $selection)
                .padding([.horizontal, .bottom], navigationInset)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(item: $sheet) { item in
            switch item {
            case .menu: AppMenu { sheet = nil }.presentationDetents([.height(300)]).presentationDragIndicator(.visible)
            case .search: PaperSearchView().presentationDetents([.large]).presentationDragIndicator(.visible)
            }
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
                        .frame(maxWidth: .infinity).frame(height: 68)
                        .background {
                            if selection == tab { selectionSurface.matchedGeometryEffect(id: "selection", in: selectionAnimation) }
                        }.contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }.padding(4).frame(height: 76)
    }
    @ViewBuilder private func trayIcon(_ tab: MainTab, selected: Bool) -> some View {
        switch tab {
        case .feed: MinimalTrayIcon(kind: .home, selected: selected).frame(width: 28, height: 28)
        case .settings: MinimalTrayIcon(kind: .person, selected: selected).frame(width: 28, height: 28)
        default: Image(systemName: selected ? tab.selectedSymbol : tab.symbol).font(.system(size: 24, weight: .regular))
        }
    }
    private var selectionSurface: some View {
        Capsule().fill(.regularMaterial)
            .overlay { Capsule().fill(.black.opacity(0.085)) }
    }
}

private struct MinimalTrayIcon: View {
    enum Kind { case home, person }
    var kind: Kind
    var selected: Bool
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 24
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }
            let stroke = StrokeStyle(lineWidth: 1.75 * scale, lineCap: .round, lineJoin: .round)
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
                else { context.stroke(house, with: .foreground, style: stroke) }
            case .person:
                let head = Path(ellipseIn: CGRect(x: 8.5 * scale, y: 2.5 * scale, width: 7 * scale, height: 7 * scale))
                var shoulders = Path()
                shoulders.move(to: point(3.5, 21))
                shoulders.addCurve(to: point(12, 14), control1: point(4, 16.7), control2: point(7.5, 14))
                shoulders.addCurve(to: point(20.5, 21), control1: point(16.5, 14), control2: point(20, 16.7))
                if selected {
                    shoulders.addLine(to: point(3.5, 21)); shoulders.closeSubpath()
                    context.fill(head, with: .foreground); context.fill(shoulders, with: .foreground)
                } else {
                    context.stroke(head, with: .foreground, style: stroke)
                    context.stroke(shoulders, with: .foreground, style: stroke)
                }
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
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Wordmark(size: 21).padding(.bottom, 6)
                Button { close(); Task { await store.fetch() } } label: { Label("Fetch new papers", systemImage: "arrow.clockwise") }
                Button { close(); selectTab(.settings) } label: { Label("Reading preferences", systemImage: "slider.horizontal.3") }
                Button { close(); openPrivacy() } label: { Label("Privacy", systemImage: "hand.raised") }
                Button { close(); store.signedIn = false } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
            }.font(Design.font(16)).foregroundStyle(Design.foreground).frame(maxWidth: .infinity, alignment: .leading).padding(28)
        }
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
