import SwiftUI

struct OverflowContainer<Content: View>: View {
    let behavior: MarkdownOverflowBehavior
    let intent: RenderedBlock.OverflowLayoutIntent
    let content: Content

    @State private var containerWidth: CGFloat = .zero
    @State private var contentWidth: CGFloat = .zero

    init(
        behavior: MarkdownOverflowBehavior,
        intent: RenderedBlock.OverflowLayoutIntent = .measure,
        @ViewBuilder content: () -> Content
    ) {
        self.behavior = behavior
        self.intent = intent
        self.content = content()
    }

    var body: some View {
        Group {
            if shouldScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    measuredContent
                }
            } else {
                measuredContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { containerWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, newValue in
                        containerWidth = newValue
                    }
            }
        )
    }

    private var measuredContent: some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { contentWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, newValue in
                            contentWidth = newValue
                        }
                }
            )
    }

    private var shouldScroll: Bool {
        guard behavior == .scrollIfNeeded else { return false }

        switch intent {
        case .natural:
            return false
        case .scroll:
            return true
        case .measure:
            return contentWidth > max(containerWidth, 1)
        }
    }
}
