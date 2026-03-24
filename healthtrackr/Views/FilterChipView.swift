import SwiftUI

struct FilterChipView: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.dataXS)
                .tracking(Typography.Tracking.monoCaps * 10)
                .foregroundStyle(isActive ? Color("accentPrimary") : Color("textTertiary"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color("accentLight") : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isActive ? Color("accentPrimary") : Color("borderDefault"),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("FilterChip_\(label)")
        .animation(.easeOut(duration: AnimationDuration.short), value: isActive)
    }
}

struct FilterChipRow: View {
    @Binding var selected: DiscoveryFeedViewModel.Filter

    var body: some View {
        HStack(spacing: Spacing.space2) {
            ForEach(DiscoveryFeedViewModel.Filter.allCases, id: \.self) { filter in
                FilterChipView(
                    label: filter.rawValue,
                    isActive: selected == filter
                ) {
                    selected = filter
                }
            }
            Spacer()
        }
    }
}

#Preview("Filter Chips") {
    struct PreviewWrapper: View {
        @State var selected: DiscoveryFeedViewModel.Filter = .all
        var body: some View {
            FilterChipRow(selected: $selected)
                .padding()
                .background(Color("bgPrimary"))
        }
    }
    return PreviewWrapper()
}
