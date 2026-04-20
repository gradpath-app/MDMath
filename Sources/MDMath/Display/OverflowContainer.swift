import SwiftUI

struct OverflowContainer<Content: View>: View {
    let behavior: MarkdownOverflowBehavior
    let content: Content

    @State private var containerWidth: CGFloat = .zero
    @State private var contentWidth: CGFloat = .zero

    init(
        behavior: MarkdownOverflowBehavior,
        @ViewBuilder content: () -> Content
    ) {
        self.behavior = behavior
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            Group {
                if behavior == .wrap || contentWidth <= max(width, 1) {
                    measuredContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        measuredContent
                    }
                }
            }
            .onAppear { containerWidth = width }
            .onChange(of: width) { _, newValue in
                containerWidth = newValue
            }
        }
        .frame(minHeight: 1)
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
}
