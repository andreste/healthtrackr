import SwiftUI

struct DiscoveryFeedView: View {
    let authManager: AuthManager
    @State private var viewModel: DiscoveryFeedViewModel

    init(
        authManager: AuthManager,
        healthKit: (any HealthKitProviding)? = nil,
        engine: (any CorrelationProviding)? = nil,
        narrator: (any NarrationProviding)? = nil
    ) {
        self.authManager = authManager
        if let healthKit, let engine, let narrator {
            self._viewModel = State(initialValue: DiscoveryFeedViewModel(
                healthKit: healthKit,
                engine: engine,
                narrator: narrator
            ))
        } else {
            self._viewModel = State(initialValue: DiscoveryFeedViewModel())
        }
    }

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
            .accessibilityIdentifier("DiscoveryFeedView")
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
                    .accessibilityIdentifier("SettingsButton")
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
                NavigationLink {
                    PatternDetailView(item: item)
                } label: {
                    PatternCardView(item: item, index: index)
                }
                .buttonStyle(.plain)
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
                Section("Data & Privacy") {
                    VStack(alignment: .leading, spacing: Spacing.space2) {
                        Text("Pattern summaries are sent to Claude API for narration.")
                            .font(Typography.bodyMD)
                            .foregroundStyle(Color("textSecondary"))
                        Link("Anthropic Privacy Policy",
                             destination: URL(string: "https://www.anthropic.com/privacy")!)
                            .font(Typography.bodyMD)
                            .foregroundStyle(Color("accentPrimary"))
                    }
                    Text("Your raw health data never leaves your device.")
                        .font(Typography.bodyMD)
                        .foregroundStyle(Color("textSecondary"))
                }

                Section("Account") {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        Text("Sign Out")
                            .font(Typography.labelMD)
                    }
                    .accessibilityIdentifier("SignOutButton")
                }

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
        .presentationDetents([.medium, .large])
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
    DiscoveryFeedView(authManager: AuthManager())
}

#Preview("Discovery Feed - Dark") {
    DiscoveryFeedView(authManager: AuthManager())
        .preferredColorScheme(.dark)
}
