import Foundation

struct MathRenderRequest: Hashable, Sendable {
    var latex: String
    var displayMode: MathNode.DisplayMode
    var fontSize: CGFloat
    var scale: CGFloat
    var foregroundHex: String
    var widthConstraint: CGFloat?

    var cacheWidthBucket: Int {
        guard let widthConstraint else { return 0 }
        return Int((widthConstraint / 16).rounded(.toNearestOrAwayFromZero))
    }
}
