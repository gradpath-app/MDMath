import SwiftUI

struct MarkdownDocumentStack: View {
    let rendered: RenderedDocumentModel
    let configuration: MarkdownConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.theme.blockSpacing) {
            ForEach(rendered.blocks) { block in
                MarkdownRenderedBlockView(block: block, configuration: configuration)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MarkdownRenderedBlockView: View {
    let block: RenderedBlock
    let configuration: MarkdownConfiguration

    var body: some View {
        switch block.content {
        case .paragraph(let content):
            MarkdownInlineRunsView(
                runs: content,
                configuration: configuration,
                font: configuration.theme.bodyFont
            )

        case .heading(let level, let content):
            MarkdownInlineRunsView(
                runs: content,
                configuration: configuration,
                font: headingFont(for: level)
            )

        case .quote(let blocks):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(configuration.theme.quoteAccentColor)
                    .frame(width: 4)
                MarkdownDocumentStack(
                    rendered: .init(blocks: blocks, unstableTail: false),
                    configuration: configuration
                )
            }

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(configuration.theme.bodyFont.weight(.bold))
                        MarkdownDocumentStack(
                            rendered: .init(blocks: item, unstableTail: false),
                            configuration: configuration
                        )
                    }
                }
            }

        case .orderedList(let start, let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\((start ?? 1) + offset).")
                            .font(configuration.theme.bodyFont.weight(.bold))
                        MarkdownDocumentStack(
                            rendered: .init(blocks: item, unstableTail: false),
                            configuration: configuration
                        )
                    }
                }
            }

        case .code(let language, let content):
            OverflowContainer(
                behavior: block.layout.overflowBehavior,
                intent: block.layout.overflowIntent
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    if let language, !language.isEmpty {
                        Text(language.uppercased())
                            .font(.caption.monospaced())
                            .foregroundStyle(configuration.theme.secondaryTextColor)
                    }
                    Text(content)
                        .font(configuration.theme.codeFont)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(configuration.theme.blockBackgroundColor, in: RoundedRectangle(cornerRadius: 14))
            }

        case .table(let table):
            OverflowContainer(
                behavior: block.layout.overflowBehavior,
                intent: block.layout.overflowIntent
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                MarkdownInlineRunsView(
                                    runs: cell.content,
                                    configuration: configuration,
                                    font: cell.isHeader ? configuration.theme.bodyFont.weight(.semibold) : configuration.theme.bodyFont
                                )
                                .padding(10)
                                .frame(minWidth: 120, alignment: .leading)
                                .background(
                                    cell.isHeader
                                        ? configuration.theme.blockBackgroundColor
                                        : Color.clear
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    Rectangle()
                                        .fill(configuration.theme.tableBorderColor)
                                        .frame(width: 1, height: rowIndex == table.rows.count - 1 ? 0 : nil)
                                        .opacity(0.4)
                                }
                            }
                        }
                        Divider()
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(configuration.theme.tableBorderColor.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

        case .math(let request):
            MathBlockSnapshotView(
                request: request,
                configuration: configuration,
                overflowBehavior: block.layout.overflowBehavior,
                overflowIntent: block.layout.overflowIntent
            )

        case .toolCall(let node):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "hammer")
                    Text(node.name)
                        .font(.headline)
                    if node.state == .streaming {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if !node.arguments.isEmpty {
                    Text(node.arguments)
                        .font(configuration.theme.codeFont)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .background(configuration.theme.blockBackgroundColor, in: RoundedRectangle(cornerRadius: 14))

        case .toolOutput(let language, let content, _):
            OverflowContainer(
                behavior: block.layout.overflowBehavior,
                intent: block.layout.overflowIntent
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language?.uppercased() ?? "OUTPUT")
                        .font(.caption.monospaced())
                        .foregroundStyle(configuration.theme.secondaryTextColor)
                    Text(content)
                        .font(configuration.theme.codeFont)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(configuration.theme.blockBackgroundColor, in: RoundedRectangle(cornerRadius: 14))
            }

        case .image(let source, let alt):
            if let url = resolvedURL(for: source) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        fallbackImageLabel(alt: alt)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        fallbackImageLabel(alt: alt)
                    }
                }
            } else {
                fallbackImageLabel(alt: alt)
            }

        case .thematicBreak:
            Divider()

        case .incomplete(let node):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("流式更新中 · \(node.kind.rawValue)")
                    .foregroundStyle(configuration.theme.secondaryTextColor)
            }
            .padding(.vertical, 4)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            .largeTitle.weight(.bold)
        case 2:
            .title.weight(.bold)
        case 3:
            .title2.weight(.semibold)
        default:
            configuration.theme.headingFont
        }
    }

    private func fallbackImageLabel(alt: String) -> some View {
        Label(alt.isEmpty ? "图片" : alt, systemImage: "photo")
            .font(configuration.theme.bodyFont)
            .foregroundStyle(configuration.theme.secondaryTextColor)
            .padding(12)
            .background(configuration.theme.blockBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
    }

    private func resolvedURL(for source: String) -> URL? {
        if let direct = URL(string: source), direct.scheme != nil {
            return direct
        }
        guard let baseURL = configuration.baseURL else { return nil }
        return URL(string: source, relativeTo: baseURL)
    }
}

private struct MarkdownInlineRunsView: View {
    let runs: [RenderInline]
    let configuration: MarkdownConfiguration
    let font: Font

    @State private var mathSnapshots: [MathRenderRequest: MathRenderPayload] = [:]

    var body: some View {
        InlineTextComposer(
            runs: runs,
            configuration: configuration,
            font: font,
            mathSnapshots: mathSnapshots
        )
        .task(id: mathRequests) {
            for request in mathRequests where mathSnapshots[request] == nil {
                if let payload = await MathRenderService.shared.render(request: request) {
                    mathSnapshots[request] = payload
                }
            }
        }
    }

    private var mathRequests: [MathRenderRequest] {
        runs.compactMap { run in
            guard case .math(let math) = run, math.displayMode == .inline else { return nil }
            return MathRenderRequest(
                latex: math.latex,
                displayMode: .inline,
                fontSize: configuration.math.fontSize,
                scale: configuration.math.inlineScale,
                foregroundHex: configuration.math.foregroundHex,
                widthConstraint: nil
            )
        }
    }
}

private struct InlineTextComposer: View {
    let runs: [RenderInline]
    let configuration: MarkdownConfiguration
    let font: Font
    let mathSnapshots: [MathRenderRequest: MathRenderPayload]

    var body: some View {
        text
            .font(font)
            .foregroundStyle(configuration.theme.textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var text: Text {
        runs.reduce(Text("")) { partial, next in
            partial + fragment(for: next)
        }
    }

    private func fragment(for inline: RenderInline) -> Text {
        switch inline {
        case .text(let text):
            return Text(verbatim: text)

        case .softBreak:
            return Text(" ")

        case .lineBreak:
            return Text("\n")

        case .emphasis(let content):
            return nestedText(for: content).italic()

        case .strong(let content):
            return nestedText(for: content).bold()

        case .code(let code):
            return Text(verbatim: code)
                .font(configuration.theme.codeFont)

        case .link(let label, _):
            return nestedText(for: label)
                .foregroundColor(configuration.theme.linkColor)
                .underline()

        case .image(let alt, _):
            return Text(verbatim: alt.isEmpty ? "[图片]" : "[\(alt)]")
                .foregroundColor(configuration.theme.secondaryTextColor)

        case .math(let math):
            guard math.displayMode == .inline else {
                return Text(verbatim: math.latex)
                    .font(configuration.theme.codeFont)
                    .foregroundColor(configuration.theme.secondaryTextColor)
            }

            let request = MathRenderRequest(
                latex: math.latex,
                displayMode: .inline,
                fontSize: configuration.math.fontSize,
                scale: configuration.math.inlineScale,
                foregroundHex: configuration.math.foregroundHex,
                widthConstraint: nil
            )

            if let payload = mathSnapshots[request] {
                return Text(Image(uiImage: payload.image))
                    .baselineOffset(-min(payload.metrics.descent, payload.metrics.height * 0.35))
            }

            return Text("□")
                .foregroundColor(configuration.theme.secondaryTextColor)
        }
    }

    private func nestedText(for content: [RenderInline]) -> Text {
        content.reduce(Text("")) { partial, next in
            partial + fragment(for: next)
        }
    }
}

private struct MathBlockSnapshotView: View {
    let request: MathRenderRequest
    let configuration: MarkdownConfiguration
    let overflowBehavior: MarkdownOverflowBehavior
    let overflowIntent: RenderedBlock.OverflowLayoutIntent

    @State private var payload: MathRenderPayload?

    var body: some View {
        OverflowContainer(behavior: overflowBehavior, intent: effectiveOverflowIntent) {
            Group {
                if let payload {
                    if effectiveOverflowIntent == .scroll {
                        Image(uiImage: payload.image)
                            .renderingMode(.original)
                            .fixedSize()
                    } else {
                        Image(uiImage: payload.image)
                            .renderingMode(.original)
                            .frame(maxWidth: .infinity, alignment: alignment)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: alignment)
                }
            }
        }
        .task(id: request) {
            if payload == nil {
                payload = await MathRenderService.shared.render(request: request)
            }
        }
    }

    private var effectiveOverflowIntent: RenderedBlock.OverflowLayoutIntent {
        guard
            let payload,
            let widthConstraint = request.widthConstraint,
            overflowBehavior == .scrollIfNeeded
        else {
            return overflowIntent
        }

        return payload.metrics.width > widthConstraint ? .scroll : .natural
    }

    private var alignment: Alignment {
        switch configuration.math.textAlignment {
        case .center:
            .center
        case .trailing:
            .trailing
        default:
            .leading
        }
    }
}
