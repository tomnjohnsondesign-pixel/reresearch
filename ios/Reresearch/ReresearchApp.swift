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
        }
    }
}

enum Destination: Hashable { case thread(String), settings, privacy }

struct RootView: View {
    @Environment(ReaderStore.self) private var store
    @State private var path: [Destination] = []
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.signedIn { FeedView() }
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
        .environment(\.returnToFeed, { path = [] })
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                Text(toast).font(Design.font(13, .medium)).padding(.horizontal, 16).padding(.vertical, 11)
                    .foregroundStyle(Design.background).background(Design.foreground, in: Capsule())
                    .padding(16).allowsHitTesting(false).transition(.opacity)
            }
        }
    }
}

private struct ReturnToFeedKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var returnToFeed: () -> Void {
        get { self[ReturnToFeedKey.self] }
        set { self[ReturnToFeedKey.self] = newValue }
    }
}

#Preview { RootView().environment(ReaderStore(persist: false)) }
