import SwiftUI

struct DiscoveryFeedView: View {
    let authManager: AuthManager
    let analytics: any AnalyticsProviding
    private let healthKit: (any HealthKitProviding)?
    @State private var viewModel: DiscoveryFeedViewModel
    @State private var hasStoredKey: Bool = KeychainHelper.read(key: PatternNarrator.keychainKey) != nil
    @State private var apiKeyInput: String = ""
    @State private var isRenarrating = false
    @State private var isSigningOut = false

    init(
        authManager: AuthManager,
        healthKit: (any HealthKitProviding)? = nil,
        engine: (any CorrelationProviding)? = nil,
        narrator: (any NarrationProviding)? = nil,
        analytics: (any AnalyticsProviding)? = nil
    ) {
        self.authManager = authManager
        self.analytics = analytics ?? MixpanelAnalyticsService()
        self.healthKit = healthKit
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
                    ProfileButtonView(
                        firstName: authManager.firstName,
                        photoURL: authManager.photoURL
                    ) {
                        viewModel.showSettings = true
                        analytics.track(event: .settingsOpened)
                    }
                }

            }
            .sheet(isPresented: $viewModel.showSettings) {
                settingsSheet
                    .onAppear {
                        hasStoredKey = KeychainHelper.read(key: PatternNarrator.keychainKey) != nil
                        apiKeyInput = ""
                    }
            }
        }
        .task {
            await viewModel.load()
        }
        .task(id: isRenarrating) {
            guard isRenarrating else { return }
            await viewModel.renarrate()
            isRenarrating = false
        }
        .task(id: isSigningOut) {
            guard isSigningOut else { return }
            await authManager.signOut()
            isSigningOut = false
        }
        .onAppear {
            analytics.track(event: .feedViewed)
        }
        .onChange(of: viewModel.selectedFilter) { _, newFilter in
            analytics.track(event: .feedFilterChanged(filter: newFilter.rawValue))
        }
        .onChange(of: viewModel.feedState) { _, newState in
            if newState == .healthKitDenied {
                analytics.track(event: .feedLoadFailed)
            }
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
                    PatternDetailView(item: item, analytics: analytics)
                } label: {
                    PatternCardView(item: item, index: index)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.screenHorizontalMargin)
                .simultaneousGesture(TapGesture().onEnded {
                    analytics.track(event: .patternCardTapped(pairId: item.pairId))
                })
            }

            // Show loading for pairs still computing
            ForEach(Array(viewModel.loadingPairIds), id: \.self) { pairId in
                LoadingPlaceholderView(pairLabel: displayLabel(for: pairId))
                    .padding(.horizontal, Spacing.screenHorizontalMargin)
            }

            if viewModel.showTomorrowFooter {
                FeedFooterView()
                    .padding(.horizontal, Spacing.screenHorizontalMargin)
                    .onAppear {
                        analytics.track(event: .feedFooterViewed)
                    }
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
                Section {
                    if hasStoredKey {
                        HStack {
                            Text("sk-ant-••••••••")
                                .font(Typography.dataSM)
                                .foregroundStyle(Color("textTertiary"))
                            Spacer()
                            Button("Remove") {
                                KeychainHelper.delete(key: PatternNarrator.keychainKey)
                                hasStoredKey = false
                                apiKeyInput = ""
                                analytics.track(event: .settingsAPIKeyRemoved)
                            }
                            .font(Typography.labelMD)
                            .foregroundStyle(Color("semanticError"))
                        }
                    } else {
                        HStack {
                            TextField("sk-ant-...", text: $apiKeyInput)
                                .font(Typography.dataSM)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .accessibilityIdentifier("APIKeyTextField")
                            if !apiKeyInput.isEmpty {
                                Button("Save") {
                                    let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    KeychainHelper.save(key: PatternNarrator.keychainKey, data: Data(trimmed.utf8))
                                    hasStoredKey = true
                                    apiKeyInput = ""
                                    viewModel.showSettings = false
                                    analytics.track(event: .settingsAPIKeySaved)
                                    isRenarrating = true
                                }
                                .font(Typography.labelMD)
                                .foregroundStyle(Color("accentPrimary"))
                            }
                        }
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Required for AI narration. Get yours at console.anthropic.com.")
                        .font(Typography.bodySM)
                        .foregroundStyle(Color("textTertiary"))
                }

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

                Section {
                    NavigationLink {
                        HealthMetricsView(healthKit: healthKit, analytics: analytics)
                    } label: {
                        Text("View Current Health Data")
                            .font(Typography.labelMD)
                            .foregroundStyle(Color("textPrimary"))
                    }
                    .accessibilityIdentifier("ViewCurrentHealthDataButton")
                } header: {
                    Text("Health Data")
                }

                Section {
                    VStack(alignment: .leading, spacing: Spacing.space2) {
                        ForEach(HealthPermissionItem.all) { item in
                            PermissionRow(icon: item.icon, label: item.label)
                        }
                    }
                    .padding(.vertical, Spacing.space1)

                    Button {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                        analytics.track(event: .settingsHealthAppOpened)
                    } label: {
                        HStack {
                            Text("Manage Permissions in Health App")
                                .font(Typography.labelMD)
                                .foregroundStyle(Color("accentPrimary"))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color("accentPrimary"))
                        }
                    }
                    .accessibilityIdentifier("ManageHealthPermissionsButton")
                } header: {
                    Text("Health Permissions")
                }

                Section("Account") {
                    Button(role: .destructive) {
                        analytics.track(event: .signedOut)
                        isSigningOut = true
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
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
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
        #if DEBUG
        .presentationDetents(
            ProcessInfo.processInfo.arguments.contains("--uitesting") ? [.large] : [.medium, .large]
        )
        #else
        .presentationDetents([.medium, .large])
        #endif
    }

    private func displayLabel(for pairId: String) -> String {
        CorrelationEngine.v1Pairs.first(where: { $0.id == pairId })?.shortLabel ?? pairId
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: Spacing.space2) {
            Image(systemName: icon)
                .foregroundStyle(Color("accentPrimary"))
                .frame(width: 20)
            Text(label)
                .font(Typography.bodyMD)
                .foregroundStyle(Color("textPrimary"))
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
