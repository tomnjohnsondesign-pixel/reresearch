import Foundation

/// One palette per feed topic, shared by the resting orb and every activity state.
enum BrandPalette: String, CaseIterable {
    case all, quantum, chemistry, biology, ai, fusion, condensedMatter

    init(topic: String?) {
        switch topic {
        case "Quantum & atomic": self = .quantum
        case "Chemistry": self = .chemistry
        case "Biology": self = .biology
        case "AI": self = .ai
        case "Fusion & plasma": self = .fusion
        case "Condensed matter": self = .condensedMatter
        default: self = .all
        }
    }
    var pigments: BrandPigments {
        switch self {
        case .all: BrandPigments([0.15, 0.43, 1, 0.20, 0.76, 0.99, 0.49, 0.25, 0.98, 0.98, 0.48, 0.84])
        case .quantum: BrandPigments([0.08, 0.37, 0.96, 0.08, 0.78, 0.96, 0.25, 0.46, 0.95, 0.45, 0.74, 1])
        case .chemistry: BrandPigments([0.98, 0.28, 0.23, 1, 0.65, 0.23, 0.94, 0.30, 0.48, 1, 0.65, 0.60])
        case .biology: BrandPigments([0.04, 0.57, 0.38, 0.23, 0.82, 0.57, 0.08, 0.66, 0.50, 0.57, 0.88, 0.51])
        case .ai: BrandPigments([0.48, 0.22, 0.96, 0.71, 0.41, 1, 0.61, 0.19, 0.89, 0.98, 0.40, 0.72])
        case .fusion: BrandPigments([0.98, 0.37, 0.06, 1, 0.75, 0.21, 0.94, 0.22, 0.13, 1, 0.61, 0.36])
        case .condensedMatter: BrandPigments([0.04, 0.53, 0.65, 0.14, 0.80, 0.81, 0.12, 0.39, 0.70, 0.47, 0.85, 0.85])
        }
    }
}

/// The twelve pigment channels used by the procedural colour field.
struct BrandPigments: Equatable {
    var values = SIMD16<Double>(repeating: 0)
    init(_ components: [Double] = []) {
        for (index, component) in components.prefix(12).enumerated() { values[index] = component }
    }
}


/// Immutable shader input between selections. In-flight fronts remain in order
/// so a new topic can enter the field already on screen without a colour jump.
struct BrandColourFlow {
    struct Front {
        let started: Double
        let pigments: BrandPigments
    }
    static let duration = 1.45
    private(set) var base = BrandPalette.all.pigments
    private(set) var fronts: [Front] = []

    mutating func select(_ pigments: BrandPigments, at time: Double) {
        while let first = fronts.first, time - first.started >= Self.duration {
            base = first.pigments
            fronts.removeFirst()
        }
        fronts.append(Front(started: time, pigments: pigments))
    }
    /// First twelve floats are the base palette; each front adds its start,
    /// duration and twelve target channels. SwiftUI supplies the array length.
    var shaderValues: [Float] {
        var values = (0..<12).map { Float(base.values[$0]) }
        for front in fronts {
            values += [Float(front.started), Float(Self.duration)]
            values += (0..<12).map { Float(front.pigments.values[$0]) }
        }
        return values
    }
    static func settled(_ pigments: BrandPigments) -> [Float] {
        (0..<12).map { Float(pigments.values[$0]) }
    }
}
