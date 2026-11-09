import Foundation

@main
struct ReaderChromeTrackingTests {
    struct Failure: Error, CustomStringConvertible { let description: String }
    static func equal(_ actual: CGFloat, _ expected: CGFloat, _ message: String) throws {
        guard abs(actual - expected) < 0.000001 else {
            throw Failure(description: "\(message): expected \(expected), got \(actual)")
        }
    }
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(description: message) }
    }

    @MainActor static func main() throws {
        let height: CGFloat = 108
        var tracking = ReaderChromeTracking()
        tracking.observe(position: 0, maximum: 1200, height: height)
        tracking.observe(position: 0.25, maximum: 1200, height: height)
        try equal(tracking.distance, 0.25, "First fractional point has no dead zone")

        for step in 2...2400 {
            let position = CGFloat(step) / 4
            tracking.observe(position: position, maximum: 1200, height: height)
            try equal(tracking.distance, min(position, height), "Forward drag consumes one point per point")
        }
        tracking.observe(position: 599.75, maximum: 1200, height: height)
        try equal(tracking.distance, 107.75, "Fractional reversal responds immediately")

        // While chrome is partially visible, the same article pixel travels
        // exactly with the header boundary, instead of being covered by it.
        let initialRelative = tracking.distance - 599.75
        for step in 1...100 {
            let position = CGFloat(599.75) - CGFloat(step)
            tracking.observe(position: position, maximum: 1200, height: height)
            try equal(tracking.distance - position, initialRelative, "Header/article join stays continuous on reversal")
        }

        tracking.observe(position: 1200, maximum: 1200, height: height)
        for position: CGFloat in [1210, 1300, 1250, 1201, 1200] {
            tracking.observe(position: position, maximum: 1200, height: height)
            try equal(tracking.distance, height, "Bottom rubber band must not reveal chrome")
        }
        tracking.observe(position: 1199, maximum: 1200, height: height)
        try equal(tracking.distance, 107, "Real reversal after bounce remains immediate")

        tracking.observe(position: 0, maximum: 1200, height: height)
        for position: CGFloat in [-1, -80, -20, 0] {
            tracking.observe(position: position, maximum: 1200, height: height)
            try equal(tracking.distance, 0, "Top bounce preserves visible chrome")
        }

        var short = ReaderChromeTracking()
        short.observe(position: 0, maximum: 38, height: height)
        short.observe(position: 38, maximum: 38, height: height)
        try equal(short.distance, 38, "Short feeds do not invent extra collapse distance")
        short.observe(position: 80, maximum: 38, height: height)
        short.observe(position: 38, maximum: 38, height: height)
        try equal(short.distance, 38, "Short-feed bounce is ignored")
        short.observe(position: 20, maximum: 20, height: height)
        try equal(short.distance, 20, "A shrinking data range clamps safely")
        short.observe(position: 0, maximum: 0, height: height)
        try equal(short.distance, 0, "Empty data restores chrome")

        tracking.observe(position: .nan, maximum: 1200, height: height)
        tracking.observe(position: .infinity, maximum: 1200, height: height)
        try equal(tracking.distance, 0, "Invalid geometry does not poison state")

        // Repeated direction changes exercise bounds and fractional precision.
        for step in 0..<10000 {
            let position = CGFloat(600 + 570 * sin(Double(step) * 0.037))
            tracking.observe(position: position, maximum: 1200, height: height)
            try require((0...height).contains(tracking.distance), "Chrome escaped its physical range")
        }

        let motion = ReaderChromeMotion()
        motion.observe(position: 0, maximum: 1200, height: height, enabled: false)
        motion.observe(position: 40, maximum: 1200, height: height, enabled: true)
        try equal(motion.distance, 40, "Controller publishes tracked distance")
        motion.reveal()
        motion.observe(position: 41, maximum: 1200, height: height, enabled: true)
        try equal(motion.distance, 1, "Forced reveal preserves native baseline")
        motion.observe(position: 80, maximum: 1200, height: height, enabled: false)
        motion.observe(position: 81, maximum: 1200, height: height, enabled: true)
        try equal(motion.distance, 2, "Suspending tracking does not accumulate a jump")

        let shortMotion = ReaderChromeMotion()
        shortMotion.observe(position: 0, maximum: 38, height: height, enabled: true)
        shortMotion.observe(position: 38, maximum: 38, height: height, enabled: true)
        shortMotion.observe(position: 58, maximum: 38, height: height, enabled: true)
        try equal(shortMotion.distance, 58, "Visible short-feed boundary follows elastic content")
        shortMotion.observe(position: 38, maximum: 38, height: height, enabled: true)
        try equal(shortMotion.distance, 38, "Elastic rebound returns to the logical collapse")

        print("Reader chrome regression checks passed: fractional drags, reversal continuity, bounce, short/empty feeds, invalid geometry, 10,000 sampled scroll positions, elastic joins, and controller resets.")
    }
}
