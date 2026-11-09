import SwiftUI

struct FeedView: View {
    @Environment(ReaderStore.self) private var store
    @State private var tab: FeedTab = .foryou
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
            }.scrollIndicators(.hidden).background(Design.background)
        }
        .background(Design.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { welcome = !store.welcomed }
        .overlay { if welcome { WelcomeView { welcome = false; store.welcomed = true } } }
    }
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Wordmark()
                Spacer()
                FetchControl(iconOnly: true)
                NavigationLink(value: Destination.settings) { Glyph(kind: .settings).foregroundStyle(Design.muted).padding(.leading, 20) }.accessibilityLabel("Settings")
            }.padding(.horizontal, 16).frame(height: 48)
            HStack(spacing: 0) {
                ForEach(FeedTab.allCases, id: \.self) { item in
                    Button { tab = item; if let topic, !topics.contains(topic) { self.topic = nil } } label: {
                        Text(item.rawValue).font(Design.font(14, tab == item ? .semibold : .regular))
                            .foregroundStyle(tab == item ? Design.foreground : Design.muted)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .overlay(alignment: .bottom) { if tab == item { Capsule().fill(Design.accent).frame(width: 48, height: 4) } }
                    }.accessibilityAddTraits(tab == item ? .isSelected : [])
                }
            }
            Rule()
            if topics.count > 1 || topic != nil {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        chip("All", count: all.count, selection: nil)
                        ForEach(topics, id: \.self) { t in chip(t, count: all.filter { $0.topic == t }.count, selection: t) }
                    }.padding(.horizontal, 16).padding(.vertical, 8)
                }.scrollIndicators(.hidden)
                Rule()
            }
        }.background(Design.background)
    }
    private func chip(_ name: String, count: Int, selection: String?) -> some View {
        Button { topic = selection } label: {
            HStack(spacing: 6) {
                Text(name)
                Text("\(count)").foregroundStyle(topic == selection ? Design.background.opacity(0.7) : Design.muted)
            }.font(Design.font(13)).padding(.horizontal, 12).padding(.vertical, 5)
                .foregroundStyle(topic == selection ? Design.background : Design.foreground)
                .background(topic == selection ? Design.foreground : Design.background, in: Capsule())
                .overlay(Capsule().stroke(topic == selection ? Design.foreground : Design.line, lineWidth: 1))
        }
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
                NavigationLink("Add a key in Settings", value: Destination.settings).buttonStyle(WebButtonStyle(primary: true, compact: true)).padding(.top, 14)
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
