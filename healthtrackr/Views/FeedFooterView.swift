import SwiftUI

struct FeedFooterView: View {
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top rule
            Rectangle()
                .fill(Color("borderSubtle"))
                .frame(maxWidth: .infinity)
                .frame(height: 1)

            // Content block
            VStack(alignment: .leading, spacing: Spacing.space3) {
                Text(String(localized: "feed.footer.eyebrow", bundle: Bundle.localization))
                    .font(Typography.dataXS)
                    .foregroundStyle(Color("textTertiary"))

                Text(String(localized: "feed.footer.headline", bundle: Bundle.localization))
                    .font(Typography.displayItalic)
                    .foregroundStyle(Color("textPrimary"))

                Text(String(localized: "feed.footer.body", bundle: Bundle.localization))
                    .font(Typography.bodySM)
                    .foregroundStyle(Color("textSecondary"))
                    .lineSpacing(Spacing.space1)
            }
            .padding(.horizontal, Spacing.space5)
            .padding(.vertical, Spacing.space5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("bgSubtle"))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: AnimationDuration.short)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("FeedFooterView")
        .accessibilityLabel(String(localized: "feed.footer.accessibilityLabel", bundle: Bundle.localization))
    }
}

#Preview("Feed Footer") {
    FeedFooterView()
        .background(Color("bgPrimary"))
}

#Preview("Feed Footer - Dark") {
    FeedFooterView()
        .background(Color("bgPrimary"))
        .preferredColorScheme(.dark)
}
