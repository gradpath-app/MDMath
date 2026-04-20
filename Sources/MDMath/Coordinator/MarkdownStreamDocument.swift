import Foundation
import Observation

@MainActor
@Observable
public final class MarkdownStreamDocument {
    public private(set) var source = ""
    public private(set) var isUpdating = false

    var renderedDocument = RenderedDocumentModel(blocks: [], unstableTail: false)

    private var toolCalls: [String: ToolCallNode] = [:]
    private let coordinator: MarkdownCoordinator
    private let configuration: MarkdownConfiguration
    private var updateTask: Task<Void, Never>?

    public init(
        initialMarkdown: String = "",
        configuration: MarkdownConfiguration = .init()
    ) {
        self.configuration = configuration
        self.coordinator = MarkdownCoordinator()
        self.source = initialMarkdown

        Task { [weak self] in
            self?.rebuild()
        }
    }

    public func apply(_ event: MarkdownStreamEvent) {
        switch event {
        case .textDelta(let delta):
            source.append(delta)

        case .replaceAll(let replacement):
            source = replacement
            toolCalls.removeAll()

        case .toolCallStart(let id, let name):
            toolCalls[id] = ToolCallNode(
                id: id,
                name: name,
                arguments: "",
                output: nil,
                outputLanguage: nil,
                state: .streaming
            )

        case .toolArgumentsDelta(let id, let delta):
            guard var toolCall = toolCalls[id] else {
                toolCalls[id] = ToolCallNode(
                    id: id,
                    name: "tool",
                    arguments: delta,
                    output: nil,
                    outputLanguage: nil,
                    state: .streaming
                )
                break
            }
            toolCall.arguments.append(delta)
            toolCalls[id] = toolCall

        case .toolCallEnd(let id):
            guard var toolCall = toolCalls[id] else { break }
            toolCall.state = .completed
            toolCalls[id] = toolCall

        case .toolOutput(let id, let content, let language):
            if var toolCall = toolCalls[id] {
                toolCall.output = content
                toolCall.outputLanguage = language
                toolCall.state = .completed
                toolCalls[id] = toolCall
            } else {
                toolCalls[id] = ToolCallNode(
                    id: id,
                    name: "tool",
                    arguments: "",
                    output: content,
                    outputLanguage: language,
                    state: .completed
                )
            }
        }

        scheduleRebuild()
    }

    private func scheduleRebuild() {
        updateTask?.cancel()
        isUpdating = true

        updateTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: configuration.streamingBatchWindow)
            rebuild()
        }
    }

    func rebuildNow() async {
        rebuild()
    }

    private func rebuild() {
        renderedDocument = coordinator.renderedDocument(
            markdown: source,
            toolCalls: Array(toolCalls.values).sorted { $0.id < $1.id },
            configuration: configuration
        )
        isUpdating = false
    }
}
