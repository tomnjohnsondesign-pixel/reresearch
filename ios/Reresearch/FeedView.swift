import SwiftUI

struct FeedScrollSample: Equatable {
    let offset: CGFloat
    let maximumOffset: CGFloat
    let viewportHeight: CGFloat
    let contentHeight: CGFloat
}

struct FeedView: View {
    @Environment(ReaderStore.self) private var store
    @Environment(\.selectMainTab) private var selectTab
    let mode: MainTab
    let chrome: ReaderChromeMotion
    var onScrollChange: (FeedScrollSample, FeedScrollSample) -> Void = { _, _ in }
    private var tab: FeedTab { mode == .saved ? .saved : mode == .queue ? .queue : .all }
    @State private var topic: String?
    @State private var welcome = false
    @State private var refreshArmed = false
    @State private var userIsPulling = false
    private var all: [Paper] { store.items(tab) }
    private var topics: [String] {
        ["Fusion & plasma", "Quantum & atomic", "Condensed matter", "Chemistry", "Biology", "AI"].filter { t in all.contains { $0.topic == t } }
    }
    private var headerHeight: CGFloat { 56 + (mode == .feed ? 52 : 44) }
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    if tab == .queue {
                        HStack(spacing: 12) {
                            Text("Fetched papers not yet in your feed, best matches first. Summarise any you want to read.").font(Design.font(13)).foregroundStyle(Design.muted)
                            FetchControl()
                        }.padding(.horizontal, Design.pageInset).padding(.vertical, 12)
                        Rule()
                    }
                    let items = store.items(tab, topic: topic)
                    if items.isEmpty { emptyState }
                    ForEach(items) { paper in
                        if tab == .queue { QueueRow(paper: paper) }
                        else { PaperCard(paper: paper, topInset: paper.id == items.first?.id ? 25 : 24) }
                    }
                    if !items.isEmpty && tab != .queue {
                        Text("You're up to date.").font(Design.font(13)).foregroundStyle(Design.muted).padding(.vertical, 40)
                    }
                }
                // A constant inset is part of the native scroll content.
                // Chrome movement never changes this inset or the viewport.
                .padding(.top, headerHeight)
            }
            .scrollIndicators(.hidden).background(Design.background).contentMargins(.bottom, 110, for: .scrollContent)
            .scrollBounceBehavior(.always)
            .modifier(ReaderViewportClip(chrome: chrome, headerHeight: headerHeight))
            .accessibilityIdentifier("paper-feed")
            .onScrollGeometryChange(for: FeedScrollSample.self) { geometry in
                FeedScrollSample(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    maximumOffset: max(0, geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom - geometry.containerSize.height),
                    viewportHeight: geometry.containerSize.height,
                    contentHeight: geometry.contentSize.height
                )
            } action: { old, new in
                onScrollChange(old, new)
                guard userIsPulling && !store.isFetching else { return }
                let distance = max(0, -new.offset)
                store.brand.pullAmount = min(1, distance / 80)
                if distance >= 80 { refreshArmed = true }
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                if newPhase == .idle { chrome.persistDiagnostics() }
                if newPhase == .interacting { userIsPulling = true }
                if oldPhase == .interacting && (newPhase == .decelerating || newPhase == .idle) {
                    userIsPulling = false
                    if refreshArmed && !store.isFetching {
                        Task { await store.fetch() }
                    } else {
                        store.brand.pullAmount = 0
                    }
                    refreshArmed = false
                }
            }
            .onDisappear { store.brand.pullAmount = 0; refreshArmed = false; userIsPulling = false }
            header
                .padding(.top, 56)
                .background(Design.background)
                .modifier(ReaderHeaderTranslation(chrome: chrome))
        }
        .background(Design.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { welcome = !store.welcomed; store.brand.selectPalette(BrandPalette(topic: topic)) }
        .onChange(of: topic) { _, value in store.brand.selectPalette(BrandPalette(topic: value)) }
        .overlay { if welcome { WelcomeView { welcome = false; store.welcomed = true } } }
    }
    @ViewBuilder private var header: some View {
        if mode == .feed { topicPills }
        else { collectionHeader }
    }
    private var topicPills: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    topicPill("All", value: nil).id("All")
                    ForEach(topics, id: \.self) { value in
                        topicPill(value, value: value).id(value)
                    }
                }.padding(.horizontal, Design.pageInset).padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("topic-filters")
            .onChange(of: topic) { _, value in
                withAnimation(.smooth(duration: 0.28)) { proxy.scrollTo(value ?? "All", anchor: .center) }
            }
        }
        .frame(height: 52).background(Design.background)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { chrome.horizontalContentFrame = $0 }
    }
    private func topicPill(_ title: String, value: String?) -> some View {
        let selected = topic == value
        return Button { topic = value } label: {
            Text(title).font(Design.font(14, .medium))
                .foregroundStyle(selected ? Design.background : Design.foreground)
                .padding(.horizontal, Design.pageInset).frame(height: 34)
                .background(selected ? Design.foreground : Design.raised, in: Capsule())
                .frame(minHeight: 44).contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var collectionHeader: some View {
        HStack {
            Text(mode.rawValue).font(Design.font(20, .bold))
            Spacer()
            if topics.count > 1 || topic != nil {
                Menu {
                    Button { topic = nil } label: {
                        if topic == nil { Label("All topics", systemImage: "checkmark") } else { Text("All topics") }
                    }
                    ForEach(topics, id: \.self) { t in Button(t) { topic = t } }
                } label: {
                    HStack(spacing: 5) { Text(topic ?? "All topics"); Image(systemName: "chevron.down").font(.system(size: 9, weight: .medium)) }.font(Design.font(13)).foregroundStyle(Design.muted).frame(height: 40)
                }
            }
        }.padding(.horizontal, Design.pageInset).frame(height: 44).foregroundStyle(Design.foreground).background(Design.background)
    }
    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 6) {
            if let topic {
                Text("Nothing in \(topic) here.").font(Design.font(15)).foregroundStyle(Design.muted)
                Button("Show all topics") { self.topic = nil }.foregroundStyle(Design.accent)
            } else if tab == .saved {
                Text("Nothing saved yet. Tap the bookmark on a post to keep it here.").font(Design.font(15)).foregroundStyle(Design.muted)
            } else if tab == .queue {
                Text("Nothing queued. Fetch new papers to fill it.").font(Design.font(14)).foregroundStyle(Design.muted)
            } else {
                Text("Add an API key to get started").font(Design.font(17, .semibold))
                Text("Threads are written with your own Anthropic, OpenAI or OpenRouter key, so your feed stays empty until you add one.").font(Design.font(14)).foregroundStyle(Design.muted)
                Button("Add a key in Settings") { selectTab(.settings) }.buttonStyle(WebButtonStyle(primary: true, compact: true)).padding(.top, 14)
            }
        }.multilineTextAlignment(.center).padding(.horizontal, 24).padding(.vertical, 64).frame(maxWidth: .infinity)
    }
}

struct PaperCard: View {
    let paper: Paper
    var showsOptions = true
    var topInset: CGFloat = 24
    @Environment(ReaderStore.self) private var store
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 8) {
                        NavigationLink(value: Destination.thread(paper.id)) {
                            PostText(text: paper.headline ?? paper.title, style: .headline)
                                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(paper.headline ?? paper.title)
                        if showsOptions { PostOptionsMenu(paper: paper) }
                    }
                    NavigationLink(value: Destination.thread(paper.id)) {
                        PostText(text: paper.hook ?? paper.abstract, style: .body)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(paper.hook ?? paper.abstract)
                    byline
                }
                ActionBar(paper: paper)
            }.padding(.top, topInset).padding(.bottom, 24)
            Color.clear.frame(height: 0)
                .overlay(alignment: .bottom) {
                    Image(store.papers.firstIndex(where: { $0.id == paper.id })?.isMultiple(of: 2) == false ? "PostDividerSecond" : "PostDivider")
                        .resizable().frame(height: 1).accessibilityHidden(true)
                }
        }.padding(.horizontal, Design.pageInset)
    }
    private var byline: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                BylineIllustration(kind: .author)
                PostText(text: paper.authors.first ?? "Unknown author", style: .metadata).fixedSize()
                if paper.authors.count > 1 { extra(paper.authors.count - 1) }
            }.fixedSize(horizontal: true, vertical: true).layoutPriority(1)
            if let institution = paper.institutions.first {
                HStack(spacing: 6) {
                    BylineIllustration(kind: .institution)
                    PostText(text: institution, style: .metadata, singleLine: true)
                        .layoutPriority(-1)
                    if paper.institutions.count > 1 { extra(paper.institutions.count - 1) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.frame(height: 18)
    }
    private func extra(_ count: Int) -> some View {
        PostText(text: "+\(count)", style: .metadata, color: UIColor(white: 0.4, alpha: 1)).fixedSize()
    }

}

struct QueueRow: View {
    let paper: Paper
    @Environment(ReaderStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(paper.authorLine) · \(paper.shortCategory) · \(paper.hoursAgo)h").font(Design.font(13)).foregroundStyle(Design.muted).lineLimit(1)
            NavigationLink(paper.title, value: Destination.thread(paper.id)).font(Design.font(15, .medium)).foregroundStyle(Design.foreground)
            Text("Matches: \(paper.tags.prefix(4).joined(separator: ", "))").font(Design.font(12.5)).foregroundStyle(Design.muted)
            if paper.failed == true && !store.writing.contains(paper.id) { Text("The request timed out. Please try again.").font(Design.font(12.5)).foregroundStyle(Design.like) }
            HStack(spacing: 12) {
                if store.writing.contains(paper.id) { Text("Writing…").foregroundStyle(Design.accent) }
                else { Button(paper.failed == true ? "Retry" : "Summarise") { store.summarise(paper) }.buttonStyle(WebButtonStyle(primary: true, compact: true)) }
                Text("score \(paper.score).0").foregroundStyle(Design.muted)
            }.font(Design.font(13)).padding(.top, 3)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, Design.pageInset).padding(.vertical, 12)
        Rule()
    }
}
