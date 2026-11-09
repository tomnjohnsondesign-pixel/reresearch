import Foundation

@main
struct BrandColourFlowTests {
    struct Failure: Error { let message: String }
    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw Failure(message: message) }
    }
    static func main() throws {
        var flow = BrandColourFlow()
        try require(flow.shaderValues.count == 12, "Rest has one palette and no fronts")
        try require(flow.base == BrandPalette.all.pigments, "Default field retains All colours")
        flow.select(BrandPalette.chemistry.pigments, at: 10)
        let firstPacket = flow.shaderValues
        try require(firstPacket.count == 26 && firstPacket[12] == 10, "Shader front has its real start time and all target channels")
        try require(firstPacket[14..<26].elementsEqual(BrandColourFlow.settled(BrandPalette.chemistry.pigments)), "Target channels match Chemistry")
        flow.select(BrandPalette.biology.pigments, at: 10.3)
        try require(flow.shaderValues.count == 40, "Interrupted fronts coexist")
        try require(Array(flow.shaderValues.prefix(26)) == firstPacket, "Retargeting preserves the entire current field's history")
        try require(flow.fronts.map(\.started) == [10, 10.3], "Retargeting does not restart the previous front")
        flow.select(BrandPalette.ai.pigments, at: 11.5)
        try require(flow.base == BrandPalette.chemistry.pigments, "Only a completed front becomes the new base")
        try require(flow.fronts.map(\.started) == [10.3, 11.5], "A still-active front survives compaction")
        flow.select(BrandPalette.quantum.pigments, at: 13)
        try require(flow.base == BrandPalette.ai.pigments && flow.fronts.count == 1, "Settled history compacts without retaining stale fronts")
        try require(flow.shaderValues.allSatisfy(\.isFinite), "Shader inputs remain finite")
        try require(BrandColourFlow.settled(BrandPalette.biology.pigments).count == 12, "Reduced-motion field contains only the destination palette")
        print("Brand colour flow checks passed: shader channels, rapid retargeting, continuous history, completed-front compaction, and reduced-motion input.")
    }
}
