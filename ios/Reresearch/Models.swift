import Foundation
import Observation

struct KeyNumber: Codable, Hashable { var value: String; var label: String }
struct Paper: Codable, Identifiable, Hashable {
    var id: String
    var slug: String
    var category: String
    var title: String
    var headline: String?
    var authors: [String]
    var institutions: [String]
    var hook: String?
    var context: String?
    var approach: String?
    var result: String?
    var caveat: String?
    var takeaway: String?
    var numbers: [KeyNumber]?
    var likeCount: Int?
    var commentCount: Int?
    var saveCount: Int?
    var tags: [String]
    var liked: Bool?
    var saved: Bool?
    var read: Bool?
    var queued: Bool?
    var failed: Bool?
    var hoursAgo: Int
    var score: Int

    var authorLine: String {
        if authors.count == 1 { return authors[0] }
        if authors.count == 2 { return authors.joined(separator: " & ") }
        return "\(authors[0]) et al."
    }
    var institutionLine: String {
        institutions.first.map { $0 + (institutions.count > 1 ? " + \(institutions.count - 1) more" : "") } ?? ""
    }
    var topic: String {
        if category.hasPrefix("cs.") || category == "stat.ML" { return "AI" }
        if category.hasPrefix("q-bio") || category.hasPrefix("biorxiv:") { return "Biology" }
        if category.hasPrefix("openalex:") || category == "physics.chem-ph" { return "Chemistry" }
        if category == "physics.plasm-ph" { return "Fusion & plasma" }
        if category == "quant-ph" { return "Quantum & atomic" }
        return "Condensed matter"
    }
    var shortCategory: String {
        if category == "openalex:1602" { return "analytical" }
        return category.replacingOccurrences(of: "physics.", with: "")
    }
    var sections: [(String, String)] {
        [("Context", context), ("Method", approach), ("Result", result), ("Caveat", caveat), ("Takeaway", takeaway)]
            .compactMap { label, value in value.map { (label, $0) } }
    }
    var abstract: String { sections.prefix(4).map(\.1).joined(separator: " ") }
}
struct TopicOption: Codable, Identifiable { var id: String; var label: String; var source: String; var short: String }
struct TopicGroup: Codable, Identifiable { var name: String; var options: [TopicOption]; var id: String { name } }
struct Keyword: Codable { var term: String; var weight: Double }
struct ModelOption: Codable, Identifiable { var id: String; var label: String; var note: String }
struct Defaults: Codable { var categories: [String]; var keywords: [Keyword]; var models: [ModelOption]; var openaiModels: [ModelOption] }
struct PrivacyBlock: Codable { var type: String; var text: String; var items: [String] }
enum FeedTab: String, CaseIterable { case all = "All", saved = "Saved", queue = "Queue" }

@MainActor @Observable
final class ReaderStore {
    let brand = BrandMotion()
    var didPresentLaunch = false
    private(set) var isFetching = false
    var papers: [Paper]
    let topicGroups: [TopicGroup] = ReaderStore.load("topics")
    let defaults: Defaults = ReaderStore.load("defaults")
    var liked: Set<String> = []
    var saved: Set<String> = []
    var hidden: Set<String> = []
    var read: Set<String> = []
    var completed: Set<String> = []
    var availableLevels: [String: Set<Int>] = [:]
    var writing: Set<String> = []
    var signedIn = true
    var email = "tom@reresearch.local"
    var selectedCategories: Set<String> = []
    var readingLevel = 4.0
    var provider = "Anthropic"
    var model = "claude-sonnet-5-5"
    var effort = "Balanced"
    var budget = "10"
    var summariesPerRun = "4"
    var keywords = ""
    var fullPDF = false
    var inspire = true
    var recommendations = true
    var welcomed = true
    var keyHints: [String: String] = [:]
    var toast: String?
    private let persist: Bool

    init(persist: Bool = true) {
        self.persist = persist
        papers = Self.load("papers")
        availableLevels = Dictionary(uniqueKeysWithValues: papers.map { ($0.id, $0.id == "model-checking" ? Set([2, 4]) : Set([4])) })
        liked = Set(papers.filter { $0.liked == true }.map(\.id))
        saved = Set(papers.filter { $0.saved == true }.map(\.id))
        read = Set(papers.filter { $0.read == true }.map(\.id))
        selectedCategories = Set(defaults.categories)
        keywords = defaults.keywords.map { $0.term + ($0.weight == 1 ? "" : ": \(String(format: "%g", $0.weight))") }.joined(separator: "\n")
        if persist, let data = UserDefaults.standard.data(forKey: "reader-state"),
           let state = try? JSONDecoder().decode(LocalState.self, from: data) {
            liked = state.liked; saved = state.saved; hidden = state.hidden; read = state.read
            selectedCategories = state.categories; readingLevel = state.level
        }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--login") { signedIn = false }
        if args.contains("--welcome") { welcomed = false }
        if args.contains("--empty") { papers = [] }
    }
    static func load<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(T.self, from: data)
        else { fatalError("Missing bundled resource: \(name)") }
        return value
    }
    func save() {
        guard persist else { return }
        let state = LocalState(liked: liked, saved: saved, hidden: hidden, read: read, categories: selectedCategories, level: readingLevel)
        if let data = try? JSONEncoder().encode(state) { UserDefaults.standard.set(data, forKey: "reader-state") }
    }
    func toggle(_ flag: String, id: String) {
        switch flag {
        case "liked": if !liked.insert(id).inserted { liked.remove(id) }
        case "saved": if !saved.insert(id).inserted { saved.remove(id) }
        default: if !hidden.insert(id).inserted { hidden.remove(id) }
        }
        save()
    }
    func items(_ tab: FeedTab, topic: String? = nil) -> [Paper] {
        var list = papers.filter { p in
            if tab == .queue { return p.queued == true && !completed.contains(p.id) && !hidden.contains(p.id) }
            if p.queued == true && !completed.contains(p.id) { return false }
            return tab == .saved ? saved.contains(p.id) : !hidden.contains(p.id)
        }
        if tab == .all { list.sort { ($0.score - (read.contains($0.id) ? 5 : 0)) > ($1.score - (read.contains($1.id) ? 5 : 0)) } }
        return topic.map { t in list.filter { $0.topic == t } } ?? list
    }
    func message(_ text: String) {
        toast = text
        Task { try? await Task.sleep(for: .seconds(3)); if toast == text { toast = nil } }
    }
    func fetch() async {
        guard !isFetching else { return }
        isFetching = true
        brand.beginRefresh()
        defer { isFetching = false; brand.endRefresh(completed: !Task.isCancelled) }
        try? await Task.sleep(for: .seconds(4.4))
    }
    func summarise(_ paper: Paper) {
        guard !writing.contains(paper.id) else { return }
        writing.insert(paper.id)
        brand.beginWork()
        Task {
            try? await Task.sleep(for: .seconds(2))
            if let i = papers.firstIndex(where: { $0.id == paper.id }) {
                papers[i].headline = paper.title
                papers[i].hook = "A comparison of measurements across different conditions shows why reliable estimates need both careful controls and an account of uncertainty."
                papers[i].context = "Reliable measurements are essential when comparing the behaviour of complex systems."
                papers[i].approach = "The researchers compared measurements across a range of controlled experimental conditions."
                papers[i].result = "The analysis identified consistent patterns alongside variations between conditions."
                papers[i].caveat = "The results apply to the conditions studied. Further work is needed to assess how well they generalise."
                papers[i].takeaway = "Comparing multiple conditions helps distinguish stable patterns from measurement noise."
            }
            writing.remove(paper.id); completed.insert(paper.id)
            brand.endWork()
        }
    }
    private struct LocalState: Codable {
        var liked: Set<String>; var saved: Set<String>; var hidden: Set<String>; var read: Set<String>
        var categories: Set<String>; var level: Double
    }
}
