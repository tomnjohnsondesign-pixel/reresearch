import SwiftUI

/// Simple role markers for author and institution credits.
struct BylineIllustration: View {
    enum Kind { case author, institution }
    let kind: Kind
    var body: some View {
        RoundedRectangle(cornerRadius: kind == .author ? 9 : 2)
            .fill(Color(red: 1, green: 235.0 / 255, blue: 235.0 / 255))
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }
}
