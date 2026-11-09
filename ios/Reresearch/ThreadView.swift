import SwiftUI
import UIKit

struct ThreadView: View {
    let paper: Paper
    @Environment(ReaderStore.self) private var store
    @State private var level = 4
    @State private var abstractOpen = false
    @State private var copied: String?
    @State private var rewriting = false
    private var current: Paper { store.papers.first { $0.id == paper.id } ?? paper }
    private var isReady: Bool { current.queued != true || store.completed.contains(paper.id) }
    private var levelName: String { SettingsView.levels[max(0, min(5, level - 1))].0 }
    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Thread")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        TopicAvatar(paper: current, size: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(current.authorLine).font(Design.font(14, .semibold)).lineLimit(1)
                            Text("\(categoryLabel) · 9 November 2026").font(Design.font(14)).foregroundStyle(Design.muted)
                        }
                    }.padding(.horizontal, 16).padding(.top, 12)
                    Text(isReady ? (current.headline ?? current.title) : current.title).font(Design.font(isReady ? 21 : 19, .bold)).lineSpacing(1).padding(.horizontal, 16).padding(.top, 12)
                    if isReady { threadBody }
                    else { pendingBody }
                }
            }.scrollIndicators(.hidden)
        }.background(Design.background).toolbar(.hidden, for: .navigationBar)
            .onAppear {
                store.read.insert(paper.id); store.save()
                level = (store.availableLevels[paper.id] ?? [4]).sorted {
                    let a = abs($0 - Int(store.readingLevel)); let b = abs($1 - Int(store.readingLevel))
                    return a == b ? $0 > $1 : a < b
                }.first ?? 4
            }
    }
    private var categoryLabel: String { store.topicGroups.flatMap(\.options).first { $0.id == paper.category }?.label ?? paper.shortCategory }
    private var hook: String {
        level == 2 && paper.id == "model-checking" ? "Smaller AI models sometimes make mistakes when a question takes several steps. Asking them to check each step helped them get more answers right, although the extra checks took longer." : (current.hook ?? "")
    }
    private var threadBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                threadPost(label: nil, text: hook, last: current.sections.isEmpty)
                ForEach(Array(current.sections.enumerated()), id: \.offset) { i, post in threadPost(label: post.0, text: post.1, last: i == current.sections.count - 1) }
            }.padding(.top, 12)
            if let numbers = current.numbers, !numbers.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                    ForEach(numbers, id: \.label) { number in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(number.value).font(Design.font(17, .semibold))
                            Text(number.label).font(Design.font(12.5)).foregroundStyle(Design.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 10).background(Design.raised, in: RoundedRectangle(cornerRadius: 12))
                    }
                }.padding(.horizontal, 16)
            }
            VStack(alignment: .leading, spacing: 3) {
                eyebrow("TL;DR")
                BodyText(text: current.takeaway ?? "")
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).overlay(RoundedRectangle(cornerRadius: 12).stroke(Design.line)).padding(.horizontal, 16).padding(.top, 16)
            FlowLayout(spacing: 6) {
                ForEach(current.tags, id: \.self) { tag in Text(tag).font(Design.font(12.5)).foregroundStyle(Design.accent).padding(.horizontal, 10).padding(.vertical, 5).background(Design.soft, in: Capsule()) }
                Text("undergraduate").font(Design.font(12.5)).foregroundStyle(Design.muted).padding(.horizontal, 10).padding(.vertical, 5).background(Design.raised, in: Capsule())
                Text("experimental").font(Design.font(12.5)).foregroundStyle(Design.muted).padding(.horizontal, 10).padding(.vertical, 5).background(Design.raised, in: Capsule())
            }.padding(.horizontal, 16).padding(.top, 12)
            ActionBar(paper: current).padding(.horizontal, 16).padding(.vertical, 10)
            if (store.liked.contains(paper.id) || store.saved.contains(paper.id)) && !store.selectedCategories.contains(paper.category) {
                HStack {
                    Text("Want more like this?").font(Design.font(13)).foregroundStyle(Design.muted)
                    Button("Add \(categoryLabel) to my topics") { store.selectedCategories.insert(paper.category); store.save() }.font(Design.font(13, .medium)).foregroundStyle(Design.accent)
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            Rule().padding(.horizontal, 16)
            credits.padding(16)
        }
    }
    private func threadPost(label: String?, text: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Circle().fill(Design.accent).frame(width: 10, height: 10).padding(.top, 8)
                Rectangle().fill(last ? Color.clear : Design.line).frame(width: 2)
            }.frame(width: 10)
            VStack(alignment: .leading, spacing: 3) {
                if let label { eyebrow(label) }
                BodyText(text: text, size: label == nil ? 17 : 15.5)
            }.padding(.bottom, 20)
        }.padding(.horizontal, 16).fixedSize(horizontal: false, vertical: true)
    }
    private var pendingBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.writing.contains(paper.id) {
                Text("Writing the thread. This usually takes under a minute; the page updates itself.").font(Design.font(14)).foregroundStyle(Design.accent).padding(12).background(Design.soft, in: RoundedRectangle(cornerRadius: 12))
            } else {
                (Text("Not written up yet. ") + Text("Add your API key").underline() + Text(" to have it written."))
                    .font(Design.font(14)).foregroundStyle(Design.accent).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Design.soft, in: RoundedRectangle(cornerRadius: 12))
            }
            BodyText(text: "We investigate how changes in experimental conditions affect the reliability of measurements and the conclusions drawn from them. By comparing observations across controlled settings, we identify the main sources of variation and discuss the limits of the resulting estimates.", size: 14)
            paperLinks
        }.padding(16)
    }
    private var credits: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) { eyebrow("Original paper"); Text(current.title).font(Design.font(15, .semibold)) }
            Text(current.authors.joined(separator: ", ")).font(Design.font(13.5)).foregroundStyle(Design.muted)
            VStack(alignment: .leading, spacing: 3) { eyebrow("Institutions"); Text(current.institutions.joined(separator: " · ")).font(Design.font(13.5)) }
            HStack(spacing: 12) { Text("arXiv").foregroundStyle(Design.muted); Text("2611.08421").foregroundStyle(Design.accent) }.font(Design.font(13))
            VStack(alignment: .leading, spacing: 8) {
                eyebrow("Cite as")
                Text("\(current.authors.joined(separator: ", ")) (2026). \(current.title).").font(Design.font(13)).lineSpacing(4).textSelection(.enabled)
                HStack {
                    copyButton("Copy citation", text: "\(current.authors.joined(separator: ", ")). (2026). \(current.title).")
                    copyButton("Copy BibTeX", text: "@article{\(current.id), title={\(current.title)}, author={\(current.authors.joined(separator: " and "))}, year={2026}}")
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Design.raised, in: RoundedRectangle(cornerRadius: 12))
            DisclosureGroup("Original abstract", isExpanded: $abstractOpen) { BodyText(text: current.abstract, size: 14).foregroundStyle(Design.muted).padding(.top, 8) }.font(Design.font(14)).foregroundStyle(Design.accent)
            paperLinks.padding(.top, 4)
            FlowLayout(spacing: 8) {
                Text("Written for \(levelName)").font(Design.font(13)).foregroundStyle(Design.accent).padding(.horizontal, 10).padding(.vertical, 5).background(Design.soft, in: Capsule())
                if !(store.availableLevels[paper.id] ?? [4]).contains(Int(store.readingLevel)) {
                    Button(rewriting ? "Rewriting…" : "Rewrite at \(SettingsView.levels[Int(store.readingLevel) - 1].0)") {
                        rewriting = true
                        Task { try? await Task.sleep(for: .seconds(2)); level = Int(store.readingLevel); store.availableLevels[paper.id, default: [4]].insert(level); rewriting = false }
                    }.buttonStyle(WebButtonStyle(compact: true)).disabled(rewriting)
                }
            }
            if (store.availableLevels[paper.id] ?? [4]).count > 1 {
                HStack {
                    Text("Also saved, free to read:").font(Design.font(13)).foregroundStyle(Design.muted)
                    ForEach((store.availableLevels[paper.id] ?? [4]).sorted().filter { $0 != level }, id: \.self) { other in
                        Button(SettingsView.levels[other - 1].0) { level = other }.buttonStyle(WebButtonStyle(compact: true))
                    }
                }
            }
            Text("Written by claude-sonnet-5-5 from the full text for $0.0470. Check the paper before citing anything.").font(Design.font(12)).foregroundStyle(Design.muted).padding(.bottom, 16)
        }
    }
    private var paperLinks: some View {
        Link("arXiv page", destination: URL(string: "https://example.org/papers/\(paper.slug)")!).buttonStyle(WebButtonStyle())
    }
    private func copyButton(_ label: String, text: String) -> some View {
        Button(copied == label ? "Copied" : label) {
            UIPasteboard.general.string = text; copied = label
            Task { try? await Task.sleep(for: .seconds(2)); copied = nil }
        }.buttonStyle(WebButtonStyle(compact: true))
    }
    private func eyebrow(_ text: String) -> some View { Text(text.uppercased()).font(Design.font(11.5, .semibold)).tracking(0.8).foregroundStyle(Design.muted) }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 360, subviews: subviews).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (_, points) = arrange(width: bounds.width, subviews: subviews)
        for (i, point) in points.enumerated() { subviews[i].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified) }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (CGSize, [CGPoint]) {
        var x: CGFloat = 0; var y: CGFloat = 0; var height: CGFloat = 0; var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += height + spacing; height = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; height = max(height, size.height)
        }
        return (CGSize(width: width, height: y + height), points)
    }
}
