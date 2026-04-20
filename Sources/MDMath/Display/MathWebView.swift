import Foundation
import UIKit
import WebKit

@MainActor
struct MathRenderPayload {
    var metrics: MathLayoutCache.Metrics
    var image: UIImage
}

@MainActor
final class MathRenderService {
    static let shared = MathRenderService()

    private let cache = MathLayoutCache.shared
    private let pool = MathWebViewPool()

    func render(request: MathRenderRequest) async -> MathRenderPayload? {
        if let metrics = cache.metrics(for: request),
           let imageData = cache.imageData(for: request),
           let image = UIImage(data: imageData) {
            return MathRenderPayload(metrics: metrics, image: image)
        }

        guard let payload = await pool.render(request: request) else { return nil }
        cache.insert(
            request: request,
            metrics: payload.metrics,
            imageData: payload.image.pngData()
        )
        return payload
    }
}

@MainActor
private final class MathWebViewPool {
    private var webViews: [MathWebView] = []

    func render(request: MathRenderRequest) async -> MathRenderPayload? {
        let webView = webViews.popLast() ?? MathWebView()
        defer { webViews.append(webView) }
        return await webView.render(request: request)
    }
}

@MainActor
private final class MathWebView: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var readinessContinuation: CheckedContinuation<Void, Never>?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()

        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 4, height: 4), configuration: configuration)
        super.init()

        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        self.webView.scrollView.isScrollEnabled = false
        self.webView.navigationDelegate = self
    }

    func render(request: MathRenderRequest) async -> MathRenderPayload? {
        guard let templateURL = Bundle.module.url(
            forResource: "math-renderer",
            withExtension: "html",
            subdirectory: "Resources/KaTeX"
        ) else {
            return nil
        }

        let baseURL = templateURL.deletingLastPathComponent()
        webView.loadFileURL(templateURL, allowingReadAccessTo: baseURL)
        await awaitReadiness()

        let script = """
        window.renderMath(\(serializedJSON(for: request)));
        """

        guard
            let rawValue = try? await webView.evaluateJavaScript(script) as? String,
            let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode(MathJavaScriptResult.self, from: data)
        else {
            return nil
        }

        let metrics = MathLayoutCache.Metrics(
            width: result.width,
            height: result.height,
            ascent: result.ascent,
            descent: result.descent
        )

        webView.frame = CGRect(x: 0, y: 0, width: max(result.width, 1), height: max(result.height, 1))
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds

        guard let image = try? await webView.takeSnapshot(configuration: configuration) else {
            return nil
        }

        return MathRenderPayload(metrics: metrics, image: image)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        readinessContinuation?.resume()
        readinessContinuation = nil
    }

    private func awaitReadiness() async {
        await withCheckedContinuation { continuation in
            readinessContinuation = continuation
        }
    }

    private func serializedJSON(for request: MathRenderRequest) -> String {
        let payload = MathJavaScriptRequest(
            latex: request.latex,
            displayMode: request.displayMode == .block,
            fontSize: request.fontSize * request.scale,
            foregroundHex: request.foregroundHex
        )
        let data = try? JSONEncoder().encode(payload)
        return String(data: data ?? Data("{}".utf8), encoding: .utf8) ?? "{}"
    }
}

private struct MathJavaScriptRequest: Codable {
    var latex: String
    var displayMode: Bool
    var fontSize: CGFloat
    var foregroundHex: String
}

private struct MathJavaScriptResult: Codable {
    var width: CGFloat
    var height: CGFloat
    var ascent: CGFloat
    var descent: CGFloat
}
