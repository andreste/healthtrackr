import SwiftUI

struct PatternCardView: View {
    let item: PatternItem
    let index: Int

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            // Metric pair badge
            Text(item.pairLabel)
                .font(Typography.dataXS)
                .tracking(Typography.Tracking.monoCaps * 10)
                .foregroundStyle(Color("textSecondary"))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .stroke(Color("borderSubtle"), lineWidth: 1)
                )

            // Headline
            Text(item.headline)
                .font(Typography.displaySM)
                .tracking(Typography.Tracking.display * 18)
                .foregroundStyle(Color("textPrimary"))
                .lineLimit(3)

            // Body
            Text(item.body)
                .font(Typography.bodyMD)
                .foregroundStyle(Color("textSecondary"))
                .lineLimit(3)
                .truncationMode(.tail)

            // Confidence chip
            ConfidenceChipView(confidence: item.confidence)

            // CTA
            Text("See full pattern")
                .font(Typography.labelMD)
                .foregroundStyle(Color("accentPrimary"))
                .underline()
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
        }
        .padding(Spacing.cardInternalPadding)
        .background(Color("bgCard"))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color("borderDefault"), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("PatternCard_\(item.pairId)")
        .accessibilityLabel("\(item.pairLabel): \(item.headline). Confidence: \(item.confidence.rawValue).")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(
                .easeOut(duration: AnimationDuration.short)
                    .delay(CardStagger.delay * Double(index))
            ) {
                appeared = true
            }
        }
    }
}

struct ConfidenceChipView: View {
    let confidence: CorrelationResult.Confidence

    private var color: Color {
        switch confidence {
        case .high: return Color("semanticSuccess")
        case .medium: return Color("semanticWarning")
        case .emerging: return Color("textTertiary")
        case .hidden: return Color("textTertiary")
        }
    }

    private var label: String {
        switch confidence {
        case .high: return "HIGH"
        case .medium: return "MEDIUM"
        case .emerging: return "EMERGING"
        case .hidden: return "HIDDEN"
        }
    }

    var body: some View {
        Text(label)
            .font(Typography.dataXS)
            .tracking(Typography.Tracking.monoCaps * 10)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
            .accessibilityLabel("Confidence: \(confidence.rawValue)")
    }
}

#Preview("Pattern Card") {
    PatternCardView(
        item: .init(
            id: "sleep_hrv_36",
            pairId: "sleep_hrv",
            pairLabel: "SLEEP + HRV",
            headline: "Your HRV Rises After Longer Sleep",
            body: "When you sleep more than 7 hours, your heart rate variability tends to increase the next morning. Based on 52 days of data.",
            confidence: .high,
            r: 0.71,
            n: 52,
            lagHours: 36,
            effectSize: 0.18,
            scatterData: [],
            metricALabel: "Sleep (hrs)",
            metricBLabel: "HRV (ms)"
        ),
        index: 0
    )
    .padding()
    .background(Color("bgPrimary"))
}

#Preview("Pattern Card - Dark") {
    PatternCardView(
        item: .init(
            id: "steps_rhr_24",
            pairId: "steps_rhr",
            pairLabel: "STEPS + HR",
            headline: "Active Days Lower Your Resting Heart Rate",
            body: "Days with higher step counts are followed by a lower resting heart rate. The effect appears about 24 hours later.",
            confidence: .medium,
            r: -0.45,
            n: 38,
            lagHours: 24,
            effectSize: -0.12,
            scatterData: [],
            metricALabel: "Steps",
            metricBLabel: "Resting HR (bpm)"
        ),
        index: 0
    )
    .padding()
    .background(Color("bgPrimary"))
    .preferredColorScheme(.dark)
}
