import SwiftUI
import UIKit
import CoreText

/// Figma's cap-to-alphabetic trim changes layout bounds, not the glyphs.
/// The ink view retains full ascent/descent and is placed outside those bounds.
struct PostText: View {
    enum Style { case metadata, headline, body, count }
    let text: String
    var style: Style
    var singleLine = false
    var color: UIColor = .black

    private var font: UIFont {
        switch style {
        case .body:
            let descriptor = CTFontDescriptorCreateWithAttributes([
                kCTFontNameAttribute: "SourceSerif4Roman-Regular",
                kCTFontVariationAttribute: [0x77676874: 340, 0x6F70737A: 16]
            ] as CFDictionary)
            return CTFontCreateWithFontDescriptor(descriptor, 16, nil) as UIFont
        default:
            let size: CGFloat = style == .headline ? 20 : 13
            let descriptor = CTFontDescriptorCreateWithAttributes([
                kCTFontNameAttribute: "Inter-Regular",
                kCTFontVariationAttribute: [0x77676874: style == .headline ? 600 : 400, 0x6F70737A: 14]
            ] as CFDictionary)
            return CTFontCreateWithFontDescriptor(descriptor, size, nil) as UIFont
        }
    }
    private var lineHeight: CGFloat {
        switch style { case .body: 25; case .headline, .count: 26; case .metadata: font.lineHeight }
    }
    private var tracking: CGFloat {
        switch style { case .headline: -0.4; case .body: 0; case .count: 0.52; case .metadata: 0 }
    }
    var body: some View {
        CapBaselineLayout(top: font.ascender - font.capHeight.rounded(), bottom: -font.descender) {
            PostInk(text: text, font: font, lineHeight: lineHeight, tracking: tracking,
                    singleLine: singleLine, color: color)
        }
        .accessibilityRepresentation { Text(text) }
    }
}

private struct CapBaselineLayout: Layout {
    let top: CGFloat
    let bottom: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ink = subviews[0].sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: ink.width, height: max(0, ink.height - top - bottom))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY - top), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

private struct PostInk: UIViewRepresentable {
    let text: String
    let font: UIFont
    let lineHeight: CGFloat
    let tracking: CGFloat
    let singleLine: Bool
    let color: UIColor
    func makeUIView(context: Context) -> PostInkView { PostInkView() }
    func updateUIView(_ view: PostInkView, context: Context) {
        view.configure(text: text, font: font, lineHeight: lineHeight, tracking: tracking,
                       singleLine: singleLine, color: color)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PostInkView, context: Context) -> CGSize? {
        uiView.measure(width: proposal.width)
    }
}

private final class PostInkView: UIView {
    private var text = ""
    private var font = UIFont.systemFont(ofSize: 13)
    private var lineHeight: CGFloat = 16
    private var tracking: CGFloat = 0
    private var singleLine = false
    private var color: UIColor = .black
    private var attributed = NSAttributedString()
    private var lines: [CTLine] = []
    private var measuredWidth: CGFloat = -1
    private var measuredSize = CGSize.zero

    init() {
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = false
        isUserInteractionEnabled = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(text: String, font: UIFont, lineHeight: CGFloat, tracking: CGFloat, singleLine: Bool, color: UIColor) {
        guard self.text != text || self.font != font || self.lineHeight != lineHeight || self.tracking != tracking
                || self.singleLine != singleLine || self.color != color else { return }
        self.text = text; self.font = font; self.lineHeight = lineHeight; self.tracking = tracking
        self.singleLine = singleLine; self.color = color
        attributed = NSAttributedString(string: text, attributes: [.font: font, .kern: tracking, .foregroundColor: color])
        measuredWidth = -1
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }
    func measure(width proposedWidth: CGFloat?) -> CGSize {
        // Round intrinsic widths outward. Fractional backing-layer rounding
        // must not turn a fitting final word into an unmeasured extra line.
        let natural = ceil(CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)))
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let width = max(1, floor((proposedWidth?.isFinite == true ? proposedWidth! : natural) * scale) / scale)
        if measuredWidth == width { return measuredSize }
        measuredWidth = width
        lines = []
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        var start = 0
        if singleLine && attributed.length > 0 {
            let fullLine = CTLineCreateWithAttributedString(attributed)
            let token = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: attributed.attributes(at: 0, effectiveRange: nil)))
            lines = [CTLineCreateTruncatedLine(fullLine, Double(width), .end, token) ?? fullLine]
        }
        while !singleLine && start < attributed.length {
            let length = max(1, CTTypesetterSuggestLineBreak(typesetter, start, Double(width + 0.01)))
            lines.append(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: length)))
            start += length
        }
        let inkHeight = font.ascender - font.descender + CGFloat(max(0, lines.count - 1)) * lineHeight
        measuredSize = CGSize(width: min(width, natural), height: lines.isEmpty ? 0 : inkHeight)
        return measuredSize
    }
    override func draw(_ rect: CGRect) {
        _ = measure(width: bounds.width)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: font.ascender)
        context.scaleBy(x: 1, y: -1)
        for (index, line) in lines.enumerated() {
            context.textPosition = CGPoint(x: 0, y: -CGFloat(index) * lineHeight)
            CTLineDraw(line, context)
        }
        context.restoreGState()
    }
}

/// Isolated Figma comparison canvas; never linked from product navigation.
struct PostStudyView: View {
    @State private var store = ReaderStore(persist: false)
    @State private var prepared = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(store.papers.prefix(2).enumerated()), id: \.element.id) { index, paper in
                        PaperCard(paper: paper, showsOptions: false, topInset: index == 0 ? 25 : 24)
                    }
                }
            }.scrollIndicators(.hidden).background(.white)
                .toolbar(.hidden, for: .navigationBar).statusBarHidden(true).ignoresSafeArea()
        }.environment(store)
            .task {
                guard !prepared, var first = store.papers.first else { return }
                prepared = true
                first.liked = true; first.saved = true
                var second = first
                second.id = "post-study-outline"; second.liked = false; second.saved = false
                store.papers = [first, second]
                store.liked = [first.id]; store.saved = [first.id]
            }
    }
}
