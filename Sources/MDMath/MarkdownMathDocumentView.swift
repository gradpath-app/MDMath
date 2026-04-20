import LaTeXSwiftUI
import SwiftUI

struct MarkdownMathDocumentView: View {
    let document: MarkdownMathDocument
    let theme: MarkdownMathTheme
    let renderMode: MarkdownMath.RenderMode

    var body: some View {
        VStack(alignment: .leading, spacing: theme.blockSpacing) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { index, block in
                blockView(block, index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func blockView(_ block: MarkdownMathBlock, index: Int) -> AnyView {
        switch block {
        case let .paragraph(text):
            return AnyView(inlineText(text, font: theme.bodyFont))

        case let .heading(level, text):
            return AnyView(inlineText(text, font: theme.headingFonts[level] ?? theme.bodyFont))

        case let .blockquote(blocks):
            return AnyView(HStack(alignment: .top, spacing: theme.contentPadding) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: theme.blockSpacing) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { nestedIndex, nestedBlock in
                        blockView(nestedBlock, index: nestedIndex)
                    }
                }
            })

        case let .unorderedList(items):
            return AnyView(VStack(alignment: .leading, spacing: theme.listItemSpacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: theme.contentPadding) {
                        Text("•")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: theme.listItemSpacing) {
                            ForEach(Array(item.enumerated()), id: \.offset) { nestedIndex, nestedBlock in
                                blockView(nestedBlock, index: nestedIndex)
                            }
                        }
                    }
                }
            })

        case let .orderedList(start, items):
            return AnyView(VStack(alignment: .leading, spacing: theme.listItemSpacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                    HStack(alignment: .top, spacing: theme.contentPadding) {
                        Text("\(start + itemIndex).")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: theme.listItemSpacing) {
                            ForEach(Array(item.enumerated()), id: \.offset) { nestedIndex, nestedBlock in
                                blockView(nestedBlock, index: nestedIndex)
                            }
                        }
                    }
                }
            })

        case let .codeBlock(language, code):
            return AnyView(ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    if let language, language.isEmpty == false {
                        Text(language.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(code)
                        .font(theme.codeFont)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(theme.contentPadding)
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.blockCornerRadius, style: .continuous)))

        case let .mathBlock(source):
            return AnyView(OverflowBlockScrollView {
                blockMath(source)
            })

        case let .image(source, alt):
            if let source, let url = URL(string: source) {
                return AnyView(VStack(alignment: .leading, spacing: 8) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            imagePlaceholder(alt.isEmpty ? source : alt)
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        @unknown default:
                            imagePlaceholder(alt.isEmpty ? source : alt)
                        }
                    }

                    if alt.isEmpty == false {
                        Text(alt)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                })
            } else {
                return AnyView(imagePlaceholder(alt))
            }

        case .thematicBreak:
            return AnyView(Divider())
        }
    }

    private func inlineText(_ source: String, font: Font) -> some View {
        return LaTeX(source)
            .font(font)
            .parsingMode(.onlyEquations)
            .processEscapes()
            .errorMode(.original)
            .imageRenderingMode(.template)
            .script(theme.usesCJKInlineMathMetrics ? .cjk : .latin)
            .renderingStyle(renderMode == .streaming ? .redactedOriginal : .wait)
            .renderingAnimation(.easeOut(duration: 0.15))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private func blockMath(_ source: String) -> some View {
        return LaTeX(source)
            .font(theme.bodyFont)
            .parsingMode(.onlyEquations)
            .processEscapes()
            .errorMode(.original)
            .blockMode(.blockViews)
            .imageRenderingMode(.template)
            .script(theme.usesCJKInlineMathMetrics ? .cjk : .latin)
            .renderingStyle(renderMode == .streaming ? .redactedOriginal : .wait)
            .renderingAnimation(.easeOut(duration: 0.15))
            .frame(maxWidth: .infinity)
    }

    private func imagePlaceholder(_ text: String) -> some View {
        RoundedRectangle(cornerRadius: theme.blockCornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.08))
            .overlay {
                Text(text.isEmpty ? "Image" : text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .frame(maxWidth: .infinity, minHeight: 120)
    }
}

private struct OverflowBlockScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content
                .frame(maxWidth: .infinity)

            ScrollView(.horizontal, showsIndicators: false) {
                content
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 1)
            }
        }
    }
}
