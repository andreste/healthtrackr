import SwiftUI

struct DiscoveryFeedView: View {
    @State private var viewModel = DiscoveryFeedViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.feedState {
                case .healthKitDenied:
                    HealthKitDeniedView {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }

                case .loading where viewModel.items.isEmpty:
                    feedContent(showingLoading: true)

                case .empty:
                    feedContent(showingEmpty: true)

                default:
                    feedContent()
                }
            }
            .background(Color("bgPrimary"))
            .navigationTitle("Discoveries")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color("textSecondary"))
                    }
                }

                if let updatedText = viewModel.lastUpdatedText {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text(updatedText)
                            .font(Typography.dataSM)
                            .foregroundStyle(Color("textTertiary"))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                settingsSheet
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Feed Content

    private func feedContent(
        showingLoading: Bool = false,
        showingEmpty: Bool = false
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                // Filter chips
                FilterChipRow(selected: $viewModel.selectedFilter)
                    .padding(.horizontal, Spacing.screenHorizontalMargin)

                if showingEmpty {
                    EmptyStateView()
                        .padding(.horizontal, Spacing.screenHorizontalMargin)
                } else if showingLoading {
                    loadingSection
                } else {
                    cardsSection
                }
            }
            .padding(.top, Spacing.space3)
            .padding(.bottom, Spacing.space7)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Cards

    private var cardsSection: some View {
        LazyVStack(spacing: Spacing.space6) {
            ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                PatternCardView(item: item, index: index)
                    .padding(.horizontal, Spacing.screenHorizontalMargin)
            }

            // Show loading for pairs still computing
            ForEach(Array(viewModel.loadingPairIds), id: \.self) { pairId in
                LoadingPlaceholderView(pairLabel: displayLabel(for: pairId))
                    .padding(.horizontal, Spacing.screenHorizontalMargin)
            }
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: Spacing.space6) {
            ForEach(CorrelationEngine.v1Pairs, id: \.id) { pair in
                LoadingPlaceholderView(pairLabel: displayLabel(for: pair.id))
                    .padding(.horizontal, Spacing.screenHorizontalMargin)
            }
        }
    }

    // MARK: - Settings

    private var settingsSheet: some View {
        NavigationStack {
            List {
                Section("About") {
                    HStack {
                        Text("Version")
                            .font(Typography.bodyMD)
                        Spacer()
                        Text("1.0")
                            .font(Typography.dataSM)
                            .foregroundStyle(Color("textTertiary"))
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.showSettings = false
                    }
                    .foregroundStyle(Color("accentPrimary"))
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func displayLabel(for pairId: String) -> String {
        switch pairId {
        case "sleep_hrv": return "Sleep + HRV"
        case "steps_rhr": return "Steps + HR"
        default: return pairId
        }
    }
}

#Preview("Discovery Feed") {
    DiscoveryFeedView()
}

#Preview("Discovery Feed - Dark") {
    DiscoveryFeedView()
        .preferredColorScheme(.dark)
}
