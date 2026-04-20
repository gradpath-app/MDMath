import Observation
import SwiftUI

public struct MarkdownBlock: View {
    public let markdown: String
    public let configuration: MarkdownConfiguration

    @State private var model = StaticMarkdownModel()
    @State private var layoutWidth: CGFloat?

    public init(
        markdown: String,
        configuration: MarkdownConfiguration = .init()
    ) {
        self.markdown = markdown
        self.configuration = configuration
    }

    public var body: some View {
        MarkdownDocumentStack(rendered: model.renderedDocument, configuration: configuration)
            .background(MarkdownLayoutWidthReader())
            .onPreferenceChange(MarkdownLayoutWidthPreferenceKey.self) { width in
                let normalized = normalize(width: width)
                guard widthBucket(for: normalized) != widthBucket(for: layoutWidth) else { return }
                layoutWidth = normalized
                model.update(markdown: markdown, configuration: configuration, layoutWidth: normalized)
            }
            .task(id: markdown) {
                model.update(markdown: markdown, configuration: configuration, layoutWidth: layoutWidth)
            }
    }
}

public struct MarkdownInline: View {
    public let markdown: String
    public let configuration: MarkdownConfiguration

    @State private var model = StaticMarkdownModel()
    @State private var layoutWidth: CGFloat?

    public init(
        markdown: String,
        configuration: MarkdownConfiguration = .init()
    ) {
        self.markdown = markdown
        self.configuration = configuration
    }

    public var body: some View {
        Group {
            if let firstParagraph = model.renderedDocument.blocks.first {
                MarkdownDocumentStack(
                    rendered: .init(blocks: [firstParagraph], unstableTail: model.renderedDocument.unstableTail),
                    configuration: configuration
                )
            } else {
                EmptyView()
            }
        }
        .background(MarkdownLayoutWidthReader())
        .onPreferenceChange(MarkdownLayoutWidthPreferenceKey.self) { width in
            let normalized = normalize(width: width)
            guard widthBucket(for: normalized) != widthBucket(for: layoutWidth) else { return }
            layoutWidth = normalized
            model.update(markdown: markdown, configuration: configuration, layoutWidth: normalized)
        }
        .task(id: markdown) {
            model.update(markdown: markdown, configuration: configuration, layoutWidth: layoutWidth)
        }
    }
}

public struct StreamingMarkdownBlock: View {
    @Bindable private var document: MarkdownStreamDocument
    public let configuration: MarkdownConfiguration

    public init(
        document: MarkdownStreamDocument,
        configuration: MarkdownConfiguration = .init()
    ) {
        self.document = document
        self.configuration = configuration
    }

    public var body: some View {
        MarkdownDocumentStack(rendered: document.renderedDocument, configuration: configuration)
            .background(MarkdownLayoutWidthReader())
            .onPreferenceChange(MarkdownLayoutWidthPreferenceKey.self) { width in
                document.updateLayoutWidth(normalize(width: width))
            }
    }
}

@MainActor
@Observable
private final class StaticMarkdownModel {
    var renderedDocument = RenderedDocumentModel(blocks: [], unstableTail: false)

    private let coordinator = MarkdownCoordinator()

    func update(
        markdown: String,
        configuration: MarkdownConfiguration,
        layoutWidth: CGFloat?
    ) {
        renderedDocument = coordinator.renderedDocument(
            markdown: markdown,
            toolCalls: [],
            configuration: configuration,
            layoutWidth: layoutWidth
        )
    }
}

private struct MarkdownLayoutWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct MarkdownLayoutWidthReader: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: MarkdownLayoutWidthPreferenceKey.self, value: geometry.size.width)
        }
    }
}

private func normalize(width: CGFloat) -> CGFloat? {
    width > 0 ? width : nil
}

private func widthBucket(for width: CGFloat?) -> Int {
    guard let width, width > 0 else { return 0 }
    return Int((width / 16).rounded(.toNearestOrAwayFromZero))
}
