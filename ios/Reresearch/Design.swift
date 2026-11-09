import SwiftUI
import UIKit

enum Design {
    static func adaptive(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    static let background = adaptive(0xffffff, 0x000000)
    static let raised = adaptive(0xf6f7f9, 0x16181c)
    static let foreground = adaptive(0x0f1419, 0xe7e9ea)
    static let muted = adaptive(0x536471, 0x8b98a5)
    static let line = adaptive(0xe6e9ec, 0x2f3336)
    static let accent = adaptive(0x5b5bd6, 0x9b9bf5)
    static let soft = adaptive(0xededfc, 0x1e1e3a)
    // Matches the visible left edge of the header menu glyph.
    static let pageInset: CGFloat = 24
    static let like = Color(red: 239/255, green: 51/255, blue: 64/255)
    static let save = Color(red: 29/255, green: 155/255, blue: 240/255)
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold: name = "Geist-Bold"
        case .semibold: name = "Geist-SemiBold"
        case .medium: name = "Geist-Medium"
        default: name = "Geist-Regular"
        }
        return .custom(name, size: size)
    }
    static func mono(_ size: CGFloat) -> Font { .custom("GeistMono-Regular", size: size) }
    static func hsl(_ hue: Double, _ saturation: Double, _ lightness: Double) -> Color {
        let brightness = lightness + saturation * min(lightness, 1 - lightness)
        let hsvSaturation = brightness == 0 ? 0 : 2 * (1 - lightness / brightness)
        return Color(hue: hue, saturation: hsvSaturation, brightness: brightness)
    }
}

struct Rule: View { var body: some View { Rectangle().fill(Design.line).frame(height: 1) } }

struct WebButtonStyle: ButtonStyle {
    var primary = false
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Design.font(compact ? 13 : 14, .semibold))
            .padding(.horizontal, compact ? 12 : 16).padding(.vertical, compact ? 6 : 8)
            .foregroundStyle(primary ? Design.background : Design.foreground)
            .background(primary ? Design.foreground : Design.background, in: Capsule())
            .overlay(Capsule().stroke(primary ? Color.clear : Design.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct BodyText: View {
    let text: String
    var size: CGFloat = 15.5
    var body: some View { Text(text).font(Design.font(size)).lineSpacing(size * 0.25).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }
}

struct TopicAvatar: View {
    var paper: Paper
    var size: CGFloat = 40
    private var hue: Double { Double(paper.category.utf8.reduce(0) { ($0 * 31 + Int($1)) % 360 }) / 360 }
    var body: some View {
        let label = String(paper.shortCategory.split(separator: " ").first ?? "paper")
        Text(label.count > 9 ? String(label.prefix(8)) : label)
            .font(Design.font(size * (label.count > 6 ? 0.2 : 0.27), .semibold)).foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Design.hsl(hue, 0.55, 0.52), Design.hsl((hue + 40/360).truncatingRemainder(dividingBy: 1), 0.6, 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            .accessibilityHidden(true)
    }
}

struct Glyph: View {
    enum Kind: Equatable { case comment, heart, bookmark, hidden, external, settings, back, refresh }
    let kind: Kind
    var filled = false
    var size: CGFloat = 20
    var body: some View {
        Canvas { context, dimensions in
            let s = dimensions.width / 24
            var p = Path()
            func move(_ x: Double,_ y: Double) { p.move(to: CGPoint(x:x*s,y:y*s)) }
            func line(_ x: Double,_ y: Double) { p.addLine(to: CGPoint(x:x*s,y:y*s)) }
            func curve(_ x: Double,_ y: Double,_ c1x: Double,_ c1y: Double,_ c2x: Double,_ c2y: Double) { p.addCurve(to: CGPoint(x:x*s,y:y*s), control1: CGPoint(x:c1x*s,y:c1y*s), control2: CGPoint(x:c2x*s,y:c2y*s)) }
            switch kind {
            case .comment:
                move(7,4); line(17,4); curve(21,8,19.2,4,21,5.8); line(21,14)
                curve(17,18,21,16.2,19.2,18); line(10,18); line(5,21); line(5,17.5)
                curve(3,14,3.8,16.8,3,15.5); line(3,8); curve(7,4,3,5.8,4.8,4); p.closeSubpath()
            case .bookmark: move(6,4); line(18,4); line(18,20); line(12,16); line(6,20); p.closeSubpath()
            case .heart:
                move(12,20); curve(5,10,12,20,5,15.65); curve(12,7.35,5,5,9,4); curve(19,10,15,4,19,5); curve(12,20,19,15.65,12,20); p.closeSubpath()
            case .external:
                move(14,4); line(20,4); line(20,10); move(20,4); line(11,13)
                move(18,14); line(18,19); curve(17,20,18,19.6,17.6,20); line(5,20); curve(4,19,4.4,20,4,19.6); line(4,7); curve(5,6,4,6.4,4.4,6); line(10,6)
            case .settings:
                move(4,7);line(14,7);move(18,7);line(20,7);move(4,17);line(8,17);move(12,17);line(20,17)
                p.addEllipse(in:CGRect(x:14*s,y:5*s,width:4*s,height:4*s));p.addEllipse(in:CGRect(x:8*s,y:15*s,width:4*s,height:4*s))
            case .back: move(19,12);line(5,12);move(11,6);line(5,12);line(11,18)
            case .refresh:
                move(20,11);curve(5.7,6.1,19,3,10,1);line(4,8);move(4,4);line(4,8);line(8,8)
                move(4,13);curve(18.3,17.9,5,21,14,23);line(20,16);move(20,20);line(20,16);line(16,16)
            case .hidden:
                move(3,3);line(21,21);move(10.6,10.6);curve(13.4,13.4,9.5,14,12,15)
                move(9.9,5.1);curve(21,12,17,3,21,10);curve(18.6,15.4,21,13,20,14)
                move(6.6,6.6);curve(3,12,4.4,8,3,10.4);curve(12,19,3,14,7,19);curve(16.4,17.9,14,19,15,18.5)
            }
            if filled { context.fill(p, with: .foreground) }
            context.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 1.8*s, lineCap: .round, lineJoin: .round))
        }.frame(width: size, height: size)
    }
}

struct BackHeader: View {
    let title: String
    var fetching = false
    @Environment(\.dismiss) private var dismiss
    @Environment(ReaderStore.self) private var store
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                Button { dismiss() } label: { Glyph(kind: .back) }.accessibilityLabel("Back to feed")
                Text(title).font(Design.font(17, .bold))
                Spacer()
                if fetching { FetchControl(iconOnly: true) }
            }.padding(.horizontal, Design.pageInset).frame(height: 48)
            Rule()
        }.background(Design.background)
    }
}

struct FetchControl: View {
    var iconOnly = false
    @Environment(ReaderStore.self) private var store
    @State private var busy = false
    var body: some View {
        Button {
            busy = true
            Task { await store.fetch(); busy = false }
        } label: {
            if iconOnly { Glyph(kind: .refresh).foregroundStyle(Design.muted) }
            else { Text(busy ? "Fetching…" : "Fetch new") }
        }.buttonStyle(FetchStyle(icon: iconOnly)).disabled(busy).accessibilityLabel(iconOnly ? "Fetch new papers" : (busy ? "Fetching…" : "Fetch new"))
    }
    struct FetchStyle: ButtonStyle {
        var icon: Bool
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.font(Design.font(13, .semibold)).padding(.horizontal, icon ? 0 : 16).padding(.vertical, icon ? 8 : 6)
                .foregroundStyle(icon ? Design.muted : Design.background)
                .background(icon ? Color.clear : Design.foreground, in: Capsule()).opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

struct ActionBar: View {
    let paper: Paper
    var showsDiscussion = true
    @Environment(ReaderStore.self) private var store
    var body: some View {
        HStack(spacing: 27) {
            Button { store.toggle("liked", id: paper.id) } label: {
                item(store.liked.contains(paper.id) ? "PostHeartFilled" : "PostHeartOutline",
                     count: adjusted(paper.likeCount, active: store.liked.contains(paper.id), initial: paper.liked == true))
            }.buttonStyle(.plain).accessibilityLabel("Like")
                .accessibilityValue(store.liked.contains(paper.id) ? "On" : "Off")
            if showsDiscussion {
                NavigationLink(value: Destination.thread(paper.id)) {
                    item("PostComment", count: paper.commentCount)
                }.buttonStyle(.plain).accessibilityLabel("Open post and comments")
            }
            Button { store.toggle("saved", id: paper.id) } label: {
                item(store.saved.contains(paper.id) ? "PostBookmarkFilled" : "PostBookmarkOutline",
                     count: adjusted(paper.saveCount, active: store.saved.contains(paper.id), initial: paper.saved == true))
            }.buttonStyle(.plain).accessibilityLabel("Save for later")
                .accessibilityValue(store.saved.contains(paper.id) ? "On" : "Off")
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func adjusted(_ count: Int?, active: Bool, initial: Bool) -> Int? {
        count.map { max(0, $0 + (active ? 1 : 0) - (initial ? 1 : 0)) }
    }
    private func item(_ asset: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Image(asset).frame(width: 18, height: 18).accessibilityHidden(true)
            if let count { PostText(text: String(count), style: .count) }
        }.frame(height: 18).contentShape(Rectangle().inset(by: -13))
    }
}

struct PostOptionsMenu: View {
    let paper: Paper
    @Environment(ReaderStore.self) private var store
    var body: some View {
        Menu {
            Button {
                store.toggle("hidden", id: paper.id)
            } label: {
                Label(store.hidden.contains(paper.id) ? "Show again" : "See less", systemImage: "eye.slash")
            }
            Link(destination: URL(string: "https://example.org/papers/\(paper.slug)")!) {
                Label("Visit source", systemImage: "arrow.up.right.square")
            }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(white: 0.6)).frame(width: 18, height: 18)
                .contentShape(Rectangle().inset(by: -13))
        }.accessibilityLabel("Post options")
    }
}
