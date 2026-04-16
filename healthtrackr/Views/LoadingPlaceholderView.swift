import SwiftUI

struct LoadingPlaceholderView: View {
    let pairLabel: String

    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            Text(String(format: String(localized: "Analyzing %@...", bundle: Bundle.localization), pairLabel))
                .font(Typography.bodySM)
                .foregroundStyle(Color("textTertiary"))

            // Shimmer lines
            VStack(alignment: .leading, spacing: Spacing.space2) {
                shimmerLine(width: 180)
                shimmerLine(width: 240)
                shimmerLine(width: 140)
            }
        }
        .padding(Spacing.cardInternalPadding)
        .background(Color("bgCard"))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(Color("borderDefault"))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "Analyzing %@ patterns", bundle: Bundle.localization),
            pairLabel.replacingOccurrences(of: "+", with: "plus")
        ))
        .accessibilityValue(String(localized: "In progress", bundle: Bundle.localization))
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 400
            }
        }
    }

    private func shimmerLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Radius.xs)
            .fill(Color("bgSubtle"))
            .frame(width: width, height: 12)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color("textTertiary").opacity(0.1),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 80)
                    .offset(x: shimmerOffset)
                    .clipped()
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.space3) {
            Text(String(localized: "No strong patterns yet.", bundle: Bundle.localization))
                .font(Typography.displaySM)
                .foregroundStyle(Color("textPrimary"))

            Text(String(localized: "Check back as more data accumulates.", bundle: Bundle.localization))
                .font(Typography.bodyMD)
                .foregroundStyle(Color("textTertiary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.space8)
        .accessibilityIdentifier("EmptyStateView")
    }
}

struct HealthKitDeniedView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.space5) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(Color("accentPrimary"))

            Text(String(localized: "Connect Apple Health", bundle: Bundle.localization))
                .font(Typography.displayLG)
                .foregroundStyle(Color("textPrimary"))

            Text(String(localized: "healthtrackr needs access to your health data to discover cross-metric patterns.", bundle: Bundle.localization))
                .font(Typography.bodyMD)
                .foregroundStyle(Color("textSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.space5)

            Button(action: onRetry) {
                Text(String(localized: "Open Settings", bundle: Bundle.localization))
                    .font(Typography.labelMD)
                    .foregroundStyle(Color("textOnAccent"))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color("accentPrimary"))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("bgPrimary"))
        .accessibilityIdentifier("HealthKitDeniedView")
    }
}

#Preview("Loading Placeholder") {
    VStack(spacing: Spacing.space6) {
        LoadingPlaceholderView(pairLabel: "Sleep + HRV")
        LoadingPlaceholderView(pairLabel: "Steps + HR")
    }
    .padding()
    .background(Color("bgPrimary"))
}

#Preview("Empty State") {
    EmptyStateView()
        .background(Color("bgPrimary"))
}

#Preview("HealthKit Denied") {
    HealthKitDeniedView(onRetry: {})
}
