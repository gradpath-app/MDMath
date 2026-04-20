import Testing
@testable import MDMath

@MainActor
struct MathLayoutCacheTests {
    @Test
    func cacheStoresMetricsByRequest() {
        let cache = MathLayoutCache.shared
        let request = MathRenderRequest(
            latex: "x^2",
            displayMode: .inline,
            fontSize: 17,
            scale: 1,
            foregroundHex: "#111827",
            widthConstraint: nil
        )
        let metrics = MathLayoutCache.Metrics(width: 20, height: 12, ascent: 9, descent: 3)

        cache.insert(request: request, metrics: metrics, imageData: nil, imageScale: nil)

        #expect(cache.metrics(for: request) == metrics)
    }

    @Test
    func mathRenderServiceProducesSnapshotPayload() async {
        let request = MathRenderRequest(
            latex: "\\int_0^1 x^2 \\, dx = \\frac{1}{3}",
            displayMode: .block,
            fontSize: 17,
            scale: 1,
            foregroundHex: "#111827",
            widthConstraint: nil
        )

        let payload = await MathRenderService.shared.render(request: request)

        #expect(payload != nil)
        #expect((payload?.metrics.width ?? 0) > 0)
        #expect((payload?.metrics.height ?? 0) > 0)
    }
}
