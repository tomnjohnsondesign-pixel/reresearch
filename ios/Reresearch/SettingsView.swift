import SwiftUI

struct SettingsView: View {
    static let levels = [
        ("Crayons", "Explain it like I'm five"),
        ("Pub quiz", "Curious, no science background needed"),
        ("Science section", "Keen reader of popular science"),
        ("Undergraduate", "Comfortable with university-level science (the default)"),
        ("Journal club", "Grad student, or working in an adjacent field"),
        ("Referee #2", "Expert in the field, here to be convinced")
    ]
    @Environment(ReaderStore.self) private var store
    @State private var tour: Int?
    @State private var extraCategories = ""
    @State private var paperInput = ""
    @State private var addedMessage: String?
    @State private var inviteInput = ""
    @State private var invited: [String] = []
    @State private var deleting = false
    @State private var openrouterModel = "anthropic/claude-sonnet-5.5"
    private let steps: [TourStep] = ReaderStore.load("tour")
    private func binding<T>(_ key: ReferenceWritableKeyPath<ReaderStore, T>) -> Binding<T> { Binding(get: { store[keyPath: key] }, set: { store[keyPath: key] = $0; store.save(); store.message("Saved") }) }
    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Settings", fetching: true)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        HStack {
                            Text("New here? It only takes a minute.").font(Design.font(13.5))
                            Spacer(minLength: 8)
                            Button("Show me around") { tour = 0 }.buttonStyle(WebButtonStyle(compact: true))
                        }.padding(.horizontal, 16).padding(.vertical, 12)
                        Rule()
                        account
                        keys.id("keys")
                        readers
                        addPaper
                        readingLevel.id("level")
                        topics.id("topics")
                        sources
                        interests.id("interests")
                        writing.id("writing")
                        spending
                        learned
                        section("Fetch now", hint: "Runs automatically every morning. Fetching now writes up the best few straight away.") { FetchControl().padding(.top, 12) }.id("fetch")
                        section("Your data") {
                            (Text("See what's stored and who handles it in the ") + Text("privacy notice").underline().foregroundColor(Design.accent) + Text("."))
                                .font(Design.font(13)).foregroundStyle(Design.muted).padding(.top, 3)
                                .overlay { NavigationLink(value: Destination.privacy) { Color.clear }.accessibilityLabel("privacy notice") }
                        }
                    }
                }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
                    .onChange(of: tour) { _, step in if let step { proxy.scrollTo(steps[step].spot, anchor: .top) } }
            }
        }.background(Design.background).toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                if let tour { tourPanel(tour).padding(.horizontal, 16).padding(.bottom, 16) }
            }
    }
    private var account: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Signed in").font(Design.font(15, .semibold))
                Text("\(store.email) · admin").font(Design.font(13)).foregroundStyle(Design.muted).lineLimit(1)
            }
            Spacer()
            Button("Sign out") { store.signedIn = false }.buttonStyle(WebButtonStyle(compact: true))
        }.padding(16).frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) { Rule() }
    }
    private var keys: some View {
        section("Your API keys", hint: "Threads are written with your own key, so you pay your provider directly. Keys are encrypted, never shown again, and only used to write your threads. Setting a spending limit with your provider is a good idea.") {
            if store.keyHints[store.provider] == nil {
                Text("Add a key for \(store.provider) (or switch provider below) to start writing threads.")
                    .font(Design.font(13)).foregroundStyle(Design.accent).padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading).background(Design.soft, in: RoundedRectangle(cornerRadius: 8)).padding(.top, 8)
            }
            VStack(spacing: 8) { ForEach(["Anthropic", "OpenAI", "OpenRouter"], id: \.self) { APIKeyCard(provider: $0) } }.padding(.top, 12)
        }
    }
    private var readers: some View {
        section("Readers", hint: "reresearch is invite only. Inviting someone creates their account and emails them a sign-in link; they add their own API key.") {
            HStack(spacing: 8) {
                WebField(placeholder: "friend@example.com", text: $inviteInput, keyboard: .emailAddress)
                Button("Invite") {
                    if inviteInput.contains("@") { invited.append(inviteInput); store.message("Invited \(inviteInput). They've been sent a sign-in link."); inviteInput = "" }
                    else { store.message("Enter a valid email address.") }
                }.buttonStyle(WebButtonStyle(primary: true))
            }.padding(.top, 12)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) { Text(store.email); Text("seen just now · no key").foregroundStyle(Design.muted) }
                    Spacer(); Text("you").foregroundStyle(Design.muted)
                }.padding(12)
                ForEach(invited, id: \.self) { email in
                    Rule()
                    HStack { Text(email); Spacer(); Button("Remove") { invited.removeAll { $0 == email } }.foregroundStyle(Design.like) }.padding(12)
                }
            }.font(Design.font(13)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Design.line)).padding(.top, 16)
        }
    }
    private var addPaper: some View {
        section("Add a paper", hint: "Paste arXiv links or ids, or DOIs (one or more). Journal papers are read from their free legal copy when one exists, otherwise from the abstract.") {
            HStack(spacing: 8) {
                WebField(placeholder: "arXiv link or DOI", text: $paperInput)
                Button("Add") {
                    if !paperInput.isEmpty { addedMessage = "Added 1 paper. Writing now; it'll appear at the top of For you in a minute or two."; paperInput = "" }
                }.buttonStyle(WebButtonStyle(primary: true))
            }.padding(.top, 12)
            if let addedMessage { Text(addedMessage).font(Design.font(13)).foregroundStyle(Design.accent).padding(.top, 8) }
        }
    }
    private var readingLevel: some View {
        section("Reading level", hint: "How much background threads assume. Changes save as you make them and apply to threads written from now on. Threads you already have keep their level. Open one to rewrite it at yours, which costs about the same as writing it did and only ever happens once: every version is kept, so going back to a level is free.") {
            let meta = Self.levels[max(0, min(5, Int(store.readingLevel) - 1))]
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(meta.0).font(Design.font(15, .semibold)).fixedSize()
                Spacer(minLength: 0)
                Text(meta.1).font(Design.font(12.5)).foregroundStyle(Design.muted).multilineTextAlignment(.trailing)
            }.padding(.top, 12)
            Slider(value: binding(\.readingLevel), in: 1...6, step: 1).tint(Design.accent).accessibilityLabel("Reading level")
            HStack { Text("Crayons"); Spacer(); Text("Referee #2") }.font(Design.font(11.5)).foregroundStyle(Design.muted)
        }
    }
    private var topics: some View {
        section("Topics", hint: "New papers in these are fetched on each run. Changes save as you make them.") {
            VStack(spacing: 8) {
                ForEach(store.topicGroups) { group in CategoryDisclosure(group: group) }
            }.padding(.top, 10)
            Text("Other arXiv categories (space separated)").font(Design.font(13)).foregroundStyle(Design.muted).padding(.top, 12)
            WebField(placeholder: "e.g. cond-mat.str-el astro-ph.GA", text: $extraCategories, mono: true).padding(.top, 4)
        }
    }
    private var sources: some View {
        section("Other sources", hint: "Checked on every run alongside your topics. Only the best matches get written up.") {
            VStack(spacing: 10) {
                CheckRow(title: "Trending in particle physics", detail: "The most-cited papers of the last six weeks on INSPIRE-HEP: what the field is arguing about.", selected: binding(\.inspire))
                CheckRow(title: "Recommended from your likes", detail: "Semantic Scholar suggests papers like the ones you like and save, and unlike the ones you hide. Papers take a few days to be indexed.", selected: binding(\.recommendations))
            }.padding(.top, 12)
        }
    }
    private var interests: some View {
        section("Interests", hint: "One per line. Optional weight after a colon (default 1; negative to steer away). Title matches count double.") {
            TextEditor(text: binding(\.keywords)).font(Design.mono(13)).scrollContentBackground(.hidden).padding(8).frame(height: 260)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.line)).padding(.top, 12).accessibilityLabel("Interests")
            Button("Add AI keywords") { store.keywords += "\nAI alignment: 2\nAI safety: 2\nlarge language model: 2\nLLM: 1.5\nreinforcement learning"; store.message("Saved") }.buttonStyle(WebButtonStyle(compact: true)).padding(.top, 8)
            numberRow("Papers summarised per run", text: binding(\.summariesPerRun)).padding(.top, 12)
        }
    }
    private var writing: some View {
        section("Writing threads", hint: "Cheaper models are faster but less careful with nuance and numbers. With Anthropic, the daily run uses the half-price batch API.") {
            HStack(alignment: .top, spacing: 8) {
                providerCard("Anthropic", note: "Claude, with half-price batches")
                providerCard("OpenAI", note: "GPT · no key yet")
                providerCard("OpenRouter", note: "Claude, GPT, Gemini, Grok… · no key yet")
            }.padding(.top, 12)
            if store.provider == "OpenRouter" {
                Text("Model").font(Design.font(13)).foregroundStyle(Design.muted).padding(.top, 12)
                WebField(placeholder: "anthropic/claude-sonnet-5.5", text: $openrouterModel, mono: true)
                Text("Only models that return structured output are listed. OpenRouter reads the extracted text and writes live (no half-price batch).").font(Design.font(12)).foregroundStyle(Design.muted).padding(.top, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(store.provider == "OpenAI" ? store.defaults.openaiModels : store.defaults.models) { model in
                        Button { store.model = model.id; store.message("Saved") } label: {
                            HStack(spacing: 12) {
                                RadioDot(selected: store.model == model.id)
                                Text(model.label).font(Design.font(14))
                                Spacer(minLength: 2)
                                Text(model.note).font(Design.font(12.5)).foregroundStyle(Design.muted).multilineTextAlignment(.trailing)
                            }.padding(.vertical, 6).padding(.horizontal, 4)
                        }.buttonStyle(.plain)
                    }
                }.padding(.top, 12)
            }
            Text("Effort").font(Design.font(14, .medium)).padding(.top, 16)
            HStack(alignment: .top, spacing: 8) {
                effortCard("Quick", "Fastest, cheapest; fine for skimming")
                effortCard("Balanced", "Default; what the costs assume")
                effortCard("Thorough", "More careful reading; costs a little more")
            }.padding(.top, 4)
            CheckRow(title: "Read the full PDF, figures included", detail: "Anthropic only. About 3× the cost. Off reads the extracted text.", selected: binding(\.fullPDF)).padding(.top, 12)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Monthly budget").font(Design.font(14))
                    Text("Writing stops for the month once this is spent.").font(Design.font(12.5)).foregroundStyle(Design.muted)
                }
                Spacer(minLength: 0); Text("$").font(Design.font(14))
                WebField(placeholder: "10", text: binding(\.budget), keyboard: .numberPad).frame(width: 80)
            }.padding(.top, 16)
        }
    }
    private var spending: some View {
        section("Spend") {
            Text("$0.2650 of $\(store.budget).00 this month across 5 threads · $0.0530 average").font(Design.font(14)).padding(.top, 4)
            hint("Threads your key paid for, estimated from token usage at list prices (OpenRouter reports its own cost). Threads someone else already wrote at your level are free.")
        }
    }
    private var learned: some View {
        section("Learned from your reading", hint: "Likes and saves boost a thread's tags; “less like this” lowers them.") {
            Text("Nothing yet.").font(Design.font(13)).foregroundStyle(Design.muted).padding(.top, 12)
        }
    }
    private func section<Content: View>(_ title: String, hint description: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(Design.font(15, .semibold))
            if let description { hint(description) }
            content()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).overlay(alignment: .bottom) { Rule() }
            .overlay {
                let spots = ["Your API keys": "keys", "Reading level": "level", "Topics": "topics", "Interests": "interests", "Writing threads": "writing", "Fetch now": "fetch"]
                if let tour, spots[title] == steps[tour].spot { RoundedRectangle(cornerRadius: 12).strokeBorder(Design.accent, lineWidth: 2).allowsHitTesting(false) }
            }
    }
    private func hint(_ text: String) -> some View { Text(text).font(Design.font(13)).lineSpacing(2).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true).padding(.top, 3) }
    private func numberRow(_ title: String, text: Binding<String>) -> some View {
        HStack { Text(title).font(Design.font(14)); Spacer(); WebField(placeholder: "4", text: text, keyboard: .numberPad).frame(width: 80) }
    }
    private func providerCard(_ title: String, note: String) -> some View {
        Button { store.provider = title; store.model = title == "OpenAI" ? "gpt-6.1-sol" : "claude-sonnet-5-5"; store.message("Saved") } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) { RadioDot(selected: store.provider == title); Text(title).font(Design.font(13.5)) }
                Text(note).font(Design.font(12)).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 8)
                .background(store.provider == title ? Design.soft : Design.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.provider == title ? Design.accent : Design.line))
        }.buttonStyle(.plain)
    }
    private func effortCard(_ title: String, _ note: String) -> some View {
        Button { store.effort = title; store.message("Saved") } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) { RadioDot(selected: store.effort == title); Text(title).font(Design.font(13.5)) }
                Text(note).font(Design.font(12)).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 8)
                .background(store.effort == title ? Design.soft : Design.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.effort == title ? Design.accent : Design.line))
        }.buttonStyle(.plain)
    }
    private func tourPanel(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(steps[index].title).font(Design.font(15, .semibold))
            Text(steps[index].body).font(Design.font(14)).opacity(0.85)
            HStack(spacing: 8) {
                Button("Skip") { tour = nil }.opacity(0.7)
                Spacer()
                Text("\(index + 1) of \(steps.count)").font(Design.font(12.5)).opacity(0.7)
                if index > 0 { Button("Back") { tour = index - 1 }.padding(.horizontal, 12).padding(.vertical, 6).overlay(Capsule().stroke(Design.background.opacity(0.3))) }
                Button(index == steps.count - 1 ? "Done" : "Next") { tour = index == steps.count - 1 ? nil : index + 1 }
                    .font(Design.font(13.5, .semibold)).padding(.horizontal, 16).padding(.vertical, 6).foregroundStyle(Design.foreground).background(Design.background, in: Capsule())
            }.font(Design.font(13.5)).padding(.top, 6)
        }.foregroundStyle(Design.background).padding(16).background(Design.foreground, in: RoundedRectangle(cornerRadius: 16)).shadow(radius: 12)
    }
    private struct TourStep: Codable { var spot: String; var title: String; var body: String }
}

struct WebField: View {
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var mono = false
    var body: some View {
        TextField(placeholder, text: $text).font(mono ? Design.mono(14) : Design.font(14)).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(keyboard)
            .padding(.horizontal, 12).padding(.vertical, 8).background(Design.background, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.line))
    }
}

struct APIKeyCard: View {
    let provider: String
    @Environment(ReaderStore.self) private var store
    @State private var input = ""
    @State private var error: String?
    private var site: String { provider == "Anthropic" ? "platform.claude.com" : provider == "OpenAI" ? "platform.openai.com" : "openrouter.ai" }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider).font(Design.font(14, .medium)); Spacer()
                if let suffix = store.keyHints[provider] {
                    Text("…\(suffix)").font(Design.mono(13)).foregroundStyle(Design.muted)
                    Button("Remove") { store.keyHints.removeValue(forKey: provider) }.font(Design.font(13)).foregroundStyle(Design.like)
                } else { Text("Not set").font(Design.font(12.5)).foregroundStyle(Design.muted) }
            }
            HStack(spacing: 8) {
                SecureField(store.keyHints[provider] == nil ? (provider == "Anthropic" ? "sk-ant-…" : provider == "OpenAI" ? "sk-proj-…" : "sk-or-…") : "Paste a new key to replace it", text: $input)
                    .font(Design.mono(13)).textContentType(.none).padding(.horizontal, 12).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.line))
                Button("Save") {
                    if input.count < 20 || input.contains(" ") { error = "That doesn't look like an API key" }
                    else { store.keyHints[provider] = String(input.suffix(4)); input = ""; error = nil }
                }.buttonStyle(WebButtonStyle(primary: true))
            }
            if let error { Text(error).font(Design.font(12.5)).foregroundStyle(Design.like) }
            else {
                (Text("Get one at ") + Text(site).foregroundColor(Design.accent) + Text(provider == "OpenAI" ? ". This is separate from ChatGPT, and the account needs some credit." : provider == "OpenRouter" ? ". One key for Claude, GPT, Gemini, Grok and more." : ". The account needs some credit."))
                    .font(Design.font(12.5)).foregroundStyle(Design.muted)
            }
        }.padding(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Design.line))
    }
}

struct RadioDot: View {
    let selected: Bool
    var body: some View { Circle().stroke(selected ? Design.accent : Design.muted.opacity(0.6), lineWidth: selected ? 4 : 1).frame(width: 13, height: 13).padding(1) }
}

struct CheckRow: View {
    let title: String
    var detail: String?
    @Binding var selected: Bool
    var body: some View {
        Button { selected.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack { RoundedRectangle(cornerRadius: 2).fill(selected ? Design.accent : Design.background); RoundedRectangle(cornerRadius: 2).stroke(selected ? Design.accent : Design.muted.opacity(0.7)); if selected { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) } }.frame(width: 16, height: 16).padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Design.font(14))
                    if let detail { Text(detail).font(Design.font(12.5)).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(selected ? "Selected" : "Not selected")
    }
}

struct CategoryDisclosure: View {
    let group: TopicGroup
    @Environment(ReaderStore.self) private var store
    @State private var open: Bool
    init(group: TopicGroup) { self.group = group; _open = State(initialValue: group.name == "Physics") }
    private var chosen: Int { group.options.filter { store.selectedCategories.contains($0.id) }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { open.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: open ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .bold)).frame(width: 8)
                    Text(group.name).font(Design.font(14, .medium))
                    Spacer()
                    Text(chosen == 0 ? "None" : "\(chosen) of \(group.options.count)").font(Design.font(12.5)).foregroundStyle(Design.muted)
                }.padding(.vertical, 7).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(group.name), \(chosen) of \(group.options.count)")
            if open {
                VStack(spacing: 0) {
                    ForEach(group.options) { option in
                        HStack(alignment: .top, spacing: 8) {
                            CheckRow(title: option.label, selected: Binding(get: { store.selectedCategories.contains(option.id) }, set: { value in if value { store.selectedCategories.insert(option.id) } else { store.selectedCategories.remove(option.id) }; store.save(); store.message("Saved") }))
                            Text(option.source).font(Design.mono(12)).foregroundStyle(Design.muted).lineLimit(1).frame(maxWidth: 135, alignment: .trailing)
                        }.padding(.horizontal, 4).padding(.vertical, 6)
                    }
                }.padding(.bottom, 4)
            }
        }.padding(.horizontal, 8).padding(.vertical, 4).overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.line))
    }
}
