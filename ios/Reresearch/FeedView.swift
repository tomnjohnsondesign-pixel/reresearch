import SwiftUI

struct FeedView: View {
    @Environment(ReaderStore.self) private var store
    @Environment(\.selectMainTab) private var selectTab
    let mode: MainTab
    @Binding var feedSort: FeedTab
    private var tab: FeedTab { mode == .saved ? .saved : mode == .queue ? .queue : feedSort }
    @State private var topic: String?
    @State private var welcome = false
    private var all: [Paper] { store.items(tab) }
    private var topics: [String] {
        ["Fusion & plasma", "Quantum & atomic", "Condensed matter", "Chemistry", "Biology", "AI"].filter { t in all.contains { $0.topic == t } }
    }
    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    if tab == .foryou || tab == .latest { randomPaper }
                    if tab == .queue {
                        HStack(spacing: 12) {
                            Text("Fetched papers not yet in your feed, best matches first. Summarise any you want to read.").font(Design.font(13)).foregroundStyle(Design.muted)
                            FetchControl()
                        }.padding(.horizontal, 16).padding(.vertical, 12)
                        Rule()
                    }
                    let items = store.items(tab, topic: topic)
                    if items.isEmpty { emptyState }
                    ForEach(items) { paper in
                        if tab == .queue { QueueRow(paper: paper) }
                        else { PaperCard(paper: paper) }
                    }
                    if !items.isEmpty && tab != .queue {
                        Text("You're up to date.").font(Design.font(13)).foregroundStyle(Design.muted).padding(.vertical, 40)
                    }
                }
            }.scrollIndicators(.hidden).background(Design.background).contentMargins(.bottom, 110, for: .scrollContent)
        }
        .background(Design.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { welcome = !store.welcomed }
        .overlay { if welcome { WelcomeView { welcome = false; store.welcomed = true } } }
    }
    private var header: some View {
        HStack {
            if mode == .feed {
                Menu {
                    ForEach([FeedTab.foryou, .latest], id: \.self) { item in
                        Button { feedSort = item } label: {
                            if feedSort == item { Label(item.rawValue, systemImage: "checkmark") }
                            else { Text(item.rawValue) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) { Text(feedSort.rawValue).font(Design.font(16, .semibold)); Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)) }
                        .frame(height: 40)
                }.accessibilityLabel("Feed order, \(feedSort.rawValue)")
            } else { Text(mode.rawValue).font(Design.font(20, .bold)) }
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
        }.padding(.horizontal, 16).frame(height: 44).foregroundStyle(Design.foreground).background(Design.background)
    }
    @ViewBuilder private var randomPaper: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let index = store.randomIndex, !store.papers.isEmpty {
                let paper = store.papers[index % store.papers.count]
                HStack {
                    Text("Random · \(paper.topic)").font(Design.font(12.5, .medium)).foregroundStyle(Design.accent)
                    Spacer()
                    Button { store.randomIndex = nil } label: { Text("✕").foregroundStyle(Design.muted) }.accessibilityLabel("Dismiss random paper")
                }
                Text(paper.title).font(Design.font(15.5, .semibold))
                Text(paper.authorLine).font(Design.font(13)).foregroundStyle(Design.muted)
                Text(paper.hook ?? paper.abstract).font(Design.font(14)).lineLimit(4)
                HStack(spacing: 8) {
                    NavigationLink("Read the thread", value: Destination.thread(paper.id)).buttonStyle(WebButtonStyle(primary: true, compact: true))
                    Button("Another") { store.randomIndex = index + 1 }.buttonStyle(WebButtonStyle(compact: true))
                }
            } else {
                HStack(spacing: 12) {
                    (Text("Random paper ").font(Design.font(13.5, .semibold)) + Text("from any field, whatever your settings").font(Design.font(13.5)).foregroundColor(Design.muted))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Surprise me") { store.randomIndex = 0 }.buttonStyle(WebButtonStyle(compact: true)).fixedSize()
                }
            }
        }.padding(.horizontal, 16).padding(.vertical, 10)
        Rule()
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
    @Environment(ReaderStore.self) private var store
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                TopicAvatar(paper: paper)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(paper.authorLine).font(Design.font(14, .semibold)).lineLimit(1)
                        Text("· \(paper.shortCategory) · \(paper.hoursAgo)h").font(Design.font(14)).foregroundStyle(Design.muted).lineLimit(1).fixedSize()
                    }
                    Text(paper.institutionLine).font(Design.font(12.5)).foregroundStyle(Design.muted).lineLimit(1)
                    NavigationLink(value: Destination.thread(paper.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(paper.headline ?? paper.title).font(Design.font(15.5, .semibold)).lineSpacing(2).foregroundStyle(store.read.contains(paper.id) ? Design.muted : Design.foreground)
                            BodyText(text: paper.hook ?? paper.abstract)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.top, 2)
                    if let numbers = paper.numbers, !numbers.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(numbers.prefix(3), id: \.label) { number in
                                (Text(number.value).font(Design.font(12.5, .semibold)) + Text(" \(number.label)").font(Design.font(12.5)).foregroundColor(Design.muted))
                                    .padding(.horizontal, 8).padding(.vertical, 4).background(Design.raised, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }.padding(.top, 10)
                    }
                    HStack(spacing: 8) {
                        NavigationLink("Show thread · \(paper.sections.count + 1)", value: Destination.thread(paper.id)).font(Design.font(13, .medium)).foregroundStyle(Design.accent)
                        if store.read.contains(paper.id) { Text("· read").font(Design.font(13)).foregroundStyle(Design.muted) }
                    }.padding(.top, 8)
                    ActionBar(paper: paper).padding(.top, 6)
                }
            }.padding(.horizontal, 16).padding(.vertical, 12)
            Rule()
        }
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
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 12)
        Rule()
    }
}
