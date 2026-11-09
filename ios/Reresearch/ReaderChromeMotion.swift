import Foundation
import CoreGraphics
import Observation

/// Pure scroll reducer. Neither viewport size nor content layout depends on it.
struct ReaderChromeTracking {
    private(set) var distance: CGFloat = 0
    private var previousPosition: CGFloat?

    mutating func observe(position: CGFloat, maximum: CGFloat, height: CGFloat) {
        guard position.isFinite, maximum.isFinite, height.isFinite, height > 0 else { return }
        let current = min(max(0, maximum), max(0, position))
        defer { previousPosition = current }
        guard let previous = previousPosition else {
            distance = min(distance, current, height)
            return
        }
        // Clamping both ends excludes top/bottom rubber band motion. Reversals
        // consume chrome immediately, including single-point movements.
        let previousClamped = min(max(0, maximum), previous)
        distance = min(height, current, max(0, distance + current - previousClamped))
    }

    mutating func synchronize(position: CGFloat, maximum: CGFloat) {
        guard position.isFinite, maximum.isFinite else { return }
        previousPosition = min(max(0, maximum), max(0, position))
    }

    mutating func reveal() { distance = 0 }
}

@MainActor @Observable
final class ReaderChromeMotion {
    private(set) var distance: CGFloat = 0
    private(set) var height: CGFloat = 108
    @ObservationIgnored private var tracking = ReaderChromeTracking()
    @ObservationIgnored var horizontalContentFrame: CGRect = .zero
    @ObservationIgnored private let diagnosticsEnabled = ProcessInfo.processInfo.arguments.contains("--scroll-diagnostics")
    @ObservationIgnored private var diagnostics: [ReaderChromeDiagnostic] = []

    var progress: CGFloat { min(1, max(0, distance / height)) }

    func observe(position: CGFloat, maximum: CGFloat, height: CGFloat, enabled: Bool,
                 viewportHeight: CGFloat = 0, contentHeight: CGFloat = 0) {
        guard position.isFinite, maximum.isFinite, height.isFinite, height > 0 else { return }
        if self.height != height { self.height = height }
        if enabled { tracking.observe(position: position, maximum: maximum, height: height) }
        else { tracking.synchronize(position: position, maximum: maximum) }
        // If a short feed rubber-bands upward while chrome is still visible,
        // its boundary accompanies the article rather than cropping its top.
        let elastic = enabled ? max(0, position - max(0, maximum)) : 0
        let visibleDistance = min(height, tracking.distance + elastic)
        if distance != visibleDistance { distance = visibleDistance }
        if diagnosticsEnabled && diagnostics.count < 12000 {
            diagnostics.append(ReaderChromeDiagnostic(time: ProcessInfo.processInfo.systemUptime,
                position: Double(position), maximum: Double(maximum), distance: Double(distance),
                height: Double(height), viewportHeight: Double(viewportHeight), contentHeight: Double(contentHeight)))
        }
    }

    func reveal() {
        tracking.reveal()
        if distance != 0 { distance = 0 }
    }

    func persistDiagnostics() {
        guard diagnosticsEnabled, !diagnostics.isEmpty else { return }
        let snapshot = diagnostics
        let url = URL.cachesDirectory.appendingPathComponent("reader-chrome-diagnostics.json")
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }
        }
    }
}

private struct ReaderChromeDiagnostic: Codable, Sendable {
    let time, position, maximum, distance, height, viewportHeight, contentHeight: Double
}
