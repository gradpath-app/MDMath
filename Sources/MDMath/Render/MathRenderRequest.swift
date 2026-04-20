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

    static func == (lhs: MathRenderRequest, rhs: MathRenderRequest) -> Bool {
        lhs.latex == rhs.latex &&
        lhs.displayMode == rhs.displayMode &&
        lhs.fontSize == rhs.fontSize &&
        lhs.scale == rhs.scale &&
        lhs.foregroundHex == rhs.foregroundHex &&
        lhs.cacheWidthBucket == rhs.cacheWidthBucket
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(latex)
        hasher.combine(displayMode)
        hasher.combine(fontSize)
        hasher.combine(scale)
        hasher.combine(foregroundHex)
        hasher.combine(cacheWidthBucket)
    }
}
