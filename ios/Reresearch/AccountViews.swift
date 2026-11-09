import SwiftUI

struct LoginView: View {
    @Environment(ReaderStore.self) private var store
    @State private var email = ""
    @State private var asking = false
    @State private var sent = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            BrandLogo(size: 64)
            Text("New papers, read as threads.").font(Design.font(14)).foregroundStyle(Design.muted).padding(.top, 4)
            Text("Pick your fields and how much background you have. Each morning the best new research is summarised into short, factual threads to read on your phone, using your own AI key.").font(Design.font(14)).lineSpacing(3).padding(.top, 12)
            if sent {
                VStack(alignment: .leading, spacing: 4) {
                    Text(asking ? "Request received" : "Check your email").font(Design.font(15, .semibold))
                    Text(asking ? "If you're approved, we'll email you an invite." : "If that email has access, a sign-in link is on its way. It works once and expires in 15 minutes.").font(Design.font(14))
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Design.accent).background(Design.soft, in: RoundedRectangle(cornerRadius: 16)).padding(.top, 24)
            } else {
                WebField(placeholder: "you@example.com", text: $email, keyboard: .emailAddress).padding(.top, 24)
                Button {
                    guard email.contains("@"), email.contains(".") else { error = "Enter a valid email address."; return }
                    sent = true
                    if !asking { Task { try? await Task.sleep(for: .seconds(2)); store.email = email; store.signedIn = true; store.welcomed = false } }
                } label: { Text(asking ? "Request access" : "Email me a sign-in link").frame(maxWidth: .infinity) }.buttonStyle(WebButtonStyle(primary: true)).padding(.top, 12)
                if let error { Text(error).font(Design.font(13)).foregroundStyle(Design.like).padding(.top, 8) }
                HStack(spacing: 3) {
                    Text(asking ? "Already have access?" : "reresearch is invite only for now.").foregroundStyle(Design.muted)
                    Button(asking ? "Sign in" : "Request access") { asking.toggle(); error = nil }.foregroundStyle(Design.accent)
                }.font(Design.font(12.5)).padding(.top, 12)
            }
            HStack(spacing: 5) {
                NavigationLink("Privacy", value: Destination.privacy)
                Text("·")
                Link("Open source", destination: URL(string: "https://github.com/mbattye/reresearch")!)
            }.font(Design.font(12.5)).foregroundStyle(Design.muted).padding(.top, 24)
            Spacer()
        }.padding(.horizontal, 32).background(Design.background).toolbar(.hidden, for: .navigationBar)
    }
}

struct WelcomeView: View {
    let close: () -> Void
    @Environment(ReaderStore.self) private var store
    @State private var provider = "Anthropic"
    @State private var fetching = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { close() }
            VStack(alignment: .leading, spacing: 0) {
                if store.keyHints.isEmpty {
                    Text("Welcome to reresearch").font(Design.font(19, .bold))
                    Text("New papers become short threads, written by an AI model using your own API key. Your feed stays empty until you add one.").font(Design.font(14)).lineSpacing(3).padding(.top, 8)
                    Text("You pay your provider directly: about 6¢ a thread on the default model, under 1¢ on the cheapest. Your key is encrypted and never shown again.").font(Design.font(14)).foregroundStyle(Design.muted).lineSpacing(3).padding(.top, 8)
                    Text("Where's your key from?").font(Design.font(13, .medium)).foregroundStyle(Design.muted).padding(.top, 16)
                    HStack(spacing: 8) {
                        ForEach(["Anthropic", "OpenAI", "OpenRouter"], id: \.self) { name in
                            Button { provider = name } label: {
                                Text(name).font(Design.font(13.5)).frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(provider == name ? Design.soft : Design.background, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(provider == name ? Design.accent : Design.line))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.top, 4)
                    APIKeyCard(provider: provider).id(provider).padding(.top, 12)
                    Button("Skip for now", action: close).font(Design.font(14)).foregroundStyle(Design.muted).frame(maxWidth: .infinity).padding(.top, 24).padding(.bottom, 8)
                } else {
                    Text("You're ready to go").font(Design.font(19, .bold))
                    Text("Every morning reresearch fetches new papers and writes up the best few. You start with particle physics, quantum and fusion. AI, chemistry, biology, your interests and how much background threads assume are all in Settings.").font(Design.font(14)).lineSpacing(3).padding(.top, 8)
                    Button { fetching = true; Task { await store.fetch(); close() } } label: { Text(fetching ? "Fetching…" : "Fetch my first papers").frame(maxWidth: .infinity) }.buttonStyle(WebButtonStyle(primary: true)).padding(.top, 16)
                    Button("Choose topics first", action: close).font(Design.font(14)).foregroundStyle(Design.muted).frame(maxWidth: .infinity).padding(.top, 16)
                }
            }.padding(20).background(Design.background, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 16).frame(maxWidth: 480).shadow(radius: 20)
        }
    }
}

struct PrivacyView: View {
    @Environment(\.returnToFeed) private var returnToFeed
    private let blocks: [PrivacyBlock] = ReaderStore.load("privacy")
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: returnToFeed) { BrandLogo() }.buttonStyle(.plain)
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    switch block.type {
                    case "h1": Text(block.text).font(Design.font(24, .bold)).padding(.top, 20)
                    case "h2": Text(block.text).font(Design.font(16, .semibold)).padding(.top, 24)
                    case "ul":
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(block.items, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) { Text("•"); BodyText(text: item, size: 14.5) }
                            }
                        }.font(Design.font(14.5)).padding(.top, 8).padding(.leading, 4)
                    default:
                        BodyText(text: block.text, size: index == 1 ? 13 : 14.5).foregroundStyle(index == 1 ? Design.muted : Design.foreground).padding(.top, index == 1 ? 4 : 8)
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 48)
        }.background(Design.background).toolbar(.hidden, for: .navigationBar)
    }
}
