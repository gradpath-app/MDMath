import Observation
import SwiftUI

public struct MarkdownBlock: View {
    public let markdown: String
    public let configuration: MarkdownConfiguration

    @State private var model = StaticMarkdownModel()

    public init(
        markdown: String,
        configuration: MarkdownConfiguration = .init()
    ) {
        self.markdown = markdown
        self.configuration = configuration
    }

    public var body: some View {
        MarkdownDocumentStack(rendered: model.renderedDocument, configuration: configuration)
            .task(id: markdown) {
                model.update(markdown: markdown, configuration: configuration)
            }
    }
}

public struct MarkdownInline: View {
    public let markdown: String
    public let configuration: MarkdownConfiguration

    @State private var model = StaticMarkdownModel()

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
        .task(id: markdown) {
            model.update(markdown: markdown, configuration: configuration)
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
    }
}

@MainActor
@Observable
private final class StaticMarkdownModel {
    var renderedDocument = RenderedDocumentModel(blocks: [], unstableTail: false)

    private let coordinator = MarkdownCoordinator()

    func update(markdown: String, configuration: MarkdownConfiguration) {
        renderedDocument = coordinator.renderedDocument(
            markdown: markdown,
            toolCalls: [],
            configuration: configuration
        )
    }
}
