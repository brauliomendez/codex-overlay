import MarkdownUI
import SwiftUI

struct MarkdownResponseView: View {
    let markdown: String
    let isPlaceholder: Bool

    var body: some View {
        if isPlaceholder {
            Text(markdown)
                .font(.body)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            Markdown(markdown)
                .markdownTheme(.gitHub)
                .markdownBlockStyle(\.codeBlock) { configuration in
                    ScrollView(.horizontal) {
                        configuration.label
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(.quaternary)
                    }
                }
                .markdownTextStyle(\.code) {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.92))
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
