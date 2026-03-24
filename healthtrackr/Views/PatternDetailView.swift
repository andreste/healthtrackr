import Charts
import SwiftUI

struct PatternDetailView: View {
    let item: PatternItem

    @State private var selectedPoint: ScatterPoint?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                headerSection
                scatterPlotSection
                statRowSection
                narrationSection
            }
            .padding(.horizontal, Spacing.screenHorizontalMargin)
            .padding(.top, Spacing.space3)
            .padding(.bottom, Spacing.space7)
        }
        .background(Color("bgPrimary"))
        .scrollIndicators(.hidden)
        .navigationTitle(item.pairLabel)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("PatternDetailView")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            Text(item.headline)
                .font(Typography.displayMD)
                .tracking(Typography.Tracking.display * 22)
                .foregroundStyle(Color("textPrimary"))

            ConfidenceChipView(confidence: item.confidence)
        }
    }

    // MARK: - Scatter Plot

    private var scatterPlotSection: some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            Chart {
                ForEach(item.scatterData) { point in
                    PointMark(
                        x: .value(item.metricALabel, point.metricA),
                        y: .value(item.metricBLabel, point.metricB)
                    )
                    .foregroundStyle(Color("accentPrimary"))
                    .symbolSize(40)
                }
            }
            .chartXAxisLabel(item.metricALabel, alignment: .center)
            .chartYAxisLabel(item.metricBLabel, alignment: .center)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(Typography.dataXS)
                        .foregroundStyle(Color("textSecondary"))
                    AxisTick()
                        .foregroundStyle(Color("borderDefault"))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(Typography.dataXS)
                        .foregroundStyle(Color("textSecondary"))
                    AxisTick()
                        .foregroundStyle(Color("borderDefault"))
                }
            }
            .frame(height: 240)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleChartTap(location: location, proxy: proxy, geo: geo)
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if let point = selectedPoint {
                    calloutView(for: point)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Scatter plot showing \(item.metricALabel) vs \(item.metricBLabel). \(item.n) data points. Correlation r equals \(String(format: "%.2f", item.r)).")
        }
        .padding(Spacing.cardInternalPadding)
        .background(Color("bgCard"))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color("borderDefault"), lineWidth: 1)
        )
    }

    private func handleChartTap(location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotFrame = geo[proxy.plotFrame!]
        let relativeX = location.x - plotFrame.origin.x
        let relativeY = location.y - plotFrame.origin.y

        guard let xValue: Double = proxy.value(atX: relativeX),
              let yValue: Double = proxy.value(atY: relativeY) else {
            selectedPoint = nil
            return
        }

        // Find nearest point
        let nearest = item.scatterData.min(by: { pointA, pointB in
            let distA = pow(pointA.metricA - xValue, 2) + pow(pointA.metricB - yValue, 2)
            let distB = pow(pointB.metricA - xValue, 2) + pow(pointB.metricB - yValue, 2)
            return distA < distB
        })

        if let nearest {
            let dist = sqrt(pow(nearest.metricA - xValue, 2) + pow(nearest.metricB - yValue, 2))
            let xRange = (item.scatterData.map(\.metricA).max() ?? 1) - (item.scatterData.map(\.metricA).min() ?? 0)
            let yRange = (item.scatterData.map(\.metricB).max() ?? 1) - (item.scatterData.map(\.metricB).min() ?? 0)
            let threshold = max(xRange, yRange) * 0.1
            selectedPoint = dist < threshold ? nearest : nil
        } else {
            selectedPoint = nil
        }
    }

    private func calloutView(for point: ScatterPoint) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(point.date, style: .date)
                .font(Typography.dataSM)
                .foregroundStyle(Color("textSecondary"))
            HStack(spacing: Spacing.space3) {
                Text(String(format: "%.1f", point.metricA))
                    .font(Typography.bodyMD)
                    .foregroundStyle(Color("textPrimary"))
                Text(String(format: "%.1f", point.metricB))
                    .font(Typography.bodyMD)
                    .foregroundStyle(Color("textPrimary"))
            }
        }
        .padding(Spacing.space2)
        .background(Color("bgSubtle"))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        .padding(Spacing.space2)
        .onTapGesture {
            selectedPoint = nil
        }
    }

    // MARK: - Stat Row

    private var statRowSection: some View {
        HStack(spacing: 0) {
            statCell(
                value: PatternDetailFormatter.effectSizeText(item.effectSize),
                label: "EFFECT"
            )
            divider
            statCell(
                value: PatternDetailFormatter.lagText(item.lagHours),
                label: "LAG"
            )
            divider
            statCell(
                value: PatternDetailFormatter.correlationText(item.r),
                label: "CORRELATION"
            )
        }
        .background(Color("bgCard"))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color("borderDefault"), lineWidth: 1)
        )
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: Spacing.space1) {
            Text(value)
                .font(.custom("GeistMono-Medium", size: 22, relativeTo: .title2))
                .foregroundStyle(Color("textPrimary"))
            Text(label)
                .font(Typography.dataXS)
                .tracking(Typography.Tracking.monoCaps * 10)
                .foregroundStyle(Color("textSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.statRowPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color("borderDefault"))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .padding(.vertical, Spacing.space2)
    }

    // MARK: - Narration Box

    private var narrationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            Text("WHAT THIS MEANS")
                .font(Typography.dataXS)
                .tracking(Typography.Tracking.monoCaps * 10 + 0.03 * 10)
                .foregroundStyle(Color("textTertiary"))

            Text(item.body)
                .font(Typography.bodyMD)
                .foregroundStyle(Color("textPrimary"))
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.cardInternalPadding)
        .background(Color("bgSubtle"))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
    }
}

// MARK: - Formatter

enum PatternDetailFormatter {
    static func effectSizeText(_ effectSize: Double) -> String {
        let pct = effectSize * 100
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", pct))%"
    }

    static func lagText(_ lagHours: Int) -> String {
        "\(lagHours)h"
    }

    static func correlationText(_ r: Double) -> String {
        "r=\(String(format: "%.2f", r))"
    }
}

// MARK: - Previews

#Preview("Pattern Detail") {
    NavigationStack {
        PatternDetailView(item: .init(
            id: "sleep_hrv_36",
            pairId: "sleep_hrv",
            pairLabel: "SLEEP + HRV",
            headline: "Your HRV Rises After Longer Sleep",
            body: "When you sleep more than 7 hours, your heart rate variability tends to increase the next morning. Based on 52 days of data.",
            confidence: .high,
            r: 0.71,
            n: 12,
            lagHours: 36,
            effectSize: 0.18,
            scatterData: (0..<12).map { i in
                .init(
                    date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                    metricA: Double.random(in: 5.5...8.5),
                    metricB: Double.random(in: 30...80)
                )
            },
            metricALabel: "Sleep (hrs)",
            metricBLabel: "HRV (ms)"
        ))
    }
}

#Preview("Pattern Detail - Dark") {
    NavigationStack {
        PatternDetailView(item: .init(
            id: "steps_rhr_24",
            pairId: "steps_rhr",
            pairLabel: "STEPS + HR",
            headline: "Active Days Lower Your Resting Heart Rate",
            body: "Days with higher step counts are followed by a lower resting heart rate. The effect appears about 24 hours later.",
            confidence: .medium,
            r: -0.45,
            n: 10,
            lagHours: 24,
            effectSize: -0.12,
            scatterData: (0..<10).map { i in
                .init(
                    date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                    metricA: Double.random(in: 3000...12000),
                    metricB: Double.random(in: 55...72)
                )
            },
            metricALabel: "Steps",
            metricBLabel: "Resting HR (bpm)"
        ))
    }
    .preferredColorScheme(.dark)
}
