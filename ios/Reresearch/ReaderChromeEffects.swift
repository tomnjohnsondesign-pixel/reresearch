import SwiftUI

/// These effects observe chrome locally. Scrolling does not invalidate the app
/// shell, rebuild paper rows, or change the scroll view's frame/content size.
struct ReaderHeaderTranslation: ViewModifier {
    let chrome: ReaderChromeMotion
    func body(content: Content) -> some View {
        content.offset(y: -chrome.distance)
            .allowsHitTesting(chrome.progress < 0.99)
            .accessibilityHidden(chrome.progress >= 0.99)
    }
}

struct ReaderTrayTranslation: ViewModifier {
    let chrome: ReaderChromeMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.offset(y: reduceMotion ? 0 : 124 * chrome.progress)
            .opacity(reduceMotion ? 1 - chrome.progress : 1)
            .allowsHitTesting(chrome.progress < 0.8)
            .accessibilityHidden(chrome.progress >= 0.99)
    }
}

struct ReaderViewportClip: ViewModifier {
    let chrome: ReaderChromeMotion
    let headerHeight: CGFloat
    func body(content: Content) -> some View {
        content.mask(ReaderViewportShape(top: max(0, headerHeight - chrome.distance)))
    }
}

private struct ReaderViewportShape: Shape {
    var top: CGFloat
    var animatableData: CGFloat {
        get { top }
        set { top = newValue }
    }
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY + top, width: rect.width,
                    height: max(0, rect.height - top)))
    }
}
