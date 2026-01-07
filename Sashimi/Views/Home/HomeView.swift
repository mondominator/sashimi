import SwiftUI

// MARK: - Theme Colors
private enum SashimiTheme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let cardBackground = Color(white: 0.12)
    static let accent = Color(red: 0.36, green: 0.68, blue: 0.90)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textTertiary = Color(white: 0.45)
    static let progressBackground = Color(white: 0.25)
    static let focusGlow = Color(red: 0.36, green: 0.68, blue: 0.90).opacity(0.5)
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedItem: BaseItemDto?
    @State private var refreshTimer: Timer?
    @State private var heroIndex: Int = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [SashimiTheme.background, Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 40) {
                        if !viewModel.heroItems.isEmpty {
                            HeroSection(
                                items: viewModel.heroItems,
                                currentIndex: $heroIndex,
                                onSelect: { item in
                                    selectedItem = item
                                }
                            )
                        }
                        
                        if !viewModel.continueWatchingItems.isEmpty {
                            ContinueWatchingRow(
                                items: viewModel.continueWatchingItems,
                                onSelect: { item in
                                    selectedItem = item
                                }
                            )
                        }
                        
                        ForEach(viewModel.libraries) { library in
                            RecentlyAddedLibraryRow(library: library, onSelect: { item in
                                selectedItem = item
                            })
                        }
                        
                        // Bottom spacing
                        Spacer()
                            .frame(height: 100)
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .fullScreenCover(item: $selectedItem) { item in
                MediaDetailView(item: item)
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    Task { await viewModel.refresh() }
                }
            }
        }
        .task {
            await viewModel.loadContent()
        }
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .overlay {
            if viewModel.isLoading && viewModel.continueWatchingItems.isEmpty {
                LoadingOverlay()
            }
        }
        .focusSection()
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await viewModel.refresh()
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Hero Section
struct HeroSection: View {
    let items: [BaseItemDto]
    @Binding var currentIndex: Int
    let onSelect: (BaseItemDto) -> Void
    
    @FocusState private var isFocused: Bool
    @State private var autoScrollTimer: Timer?
    
    private var safeIndex: Int {
        guard !items.isEmpty else { return 0 }
        return min(currentIndex, items.count - 1)
    }

    private var currentItem: BaseItemDto {
        items[safeIndex]
    }

    // Check if item has backdrop images (regular shows have it, YouTube doesn't)
    private var itemHasBackdrop: Bool {
        if let tags = currentItem.backdropImageTags, !tags.isEmpty {
            return true
        }
        return false
    }

    private var heroImageId: String {
        // For episodes with backdrops (regular shows), use series backdrop
        // For episodes without backdrops (YouTube), use episode's own thumbnail
        if currentItem.type == .episode {
            return itemHasBackdrop ? (currentItem.seriesId ?? currentItem.id) : currentItem.id
        }
        return currentItem.id
    }

    private var heroImageType: String {
        // YouTube episodes don't have backdrops, use Primary (thumbnail)
        if currentItem.type == .episode && !itemHasBackdrop {
            return "Primary"
        }
        return "Backdrop"
    }

    private func startAutoScroll() {
        autoScrollTimer?.invalidate()
        guard items.count > 1 else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                currentIndex = (currentIndex + 1) % items.count
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
    
    var body: some View {
        Button(action: { onSelect(currentItem) }) {
            ZStack(alignment: .bottomLeading) {
                AsyncItemImage(
                    itemId: heroImageId,
                    imageType: heroImageType,
                    maxWidth: 1920,
                    contentMode: .fit,
                    fallbackImageTypes: ["Thumb", "Primary"]
                )
                .id(currentItem.id)
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .background(Color.black)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: currentItem.id)
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        .clear,
                        .clear,
                        SashimiTheme.background.opacity(0.7),
                        SashimiTheme.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Vignette sides
                HStack {
                    LinearGradient(
                        colors: [SashimiTheme.background.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 300)
                    Spacer()
                }
                
                // Content
                VStack(alignment: .leading, spacing: 16) {
                    if let type = currentItem.type {
                        Text(type.rawValue.uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(SashimiTheme.accent)
                    }
                    
                    Text(currentItem.type == .episode ? (currentItem.seriesName ?? currentItem.name) : currentItem.name)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(SashimiTheme.textPrimary)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 3)
                    
                    if currentItem.type == .episode {
                        Text(formatEpisodeInfo(currentItem))
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(SashimiTheme.textSecondary)
                    }
                    
                    HStack(spacing: 14) {
                        if let year = currentItem.productionYear {
                            Text(String(year))
                                .foregroundStyle(SashimiTheme.textSecondary)
                        }
                        
                        if let runtime = currentItem.runTimeTicks {
                            Text(formatRuntime(runtime))
                                .foregroundStyle(SashimiTheme.textSecondary)
                        }
                        
                        if let rating = currentItem.communityRating {
                            HStack(spacing: 6) {
                                Image("TMDBLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 26)
                                Text(String(format: "%.1f", rating))
                                    .foregroundStyle(SashimiTheme.textPrimary)
                            }
                        }
                    }
                    .font(.system(size: 22))
                    
                    if let overview = currentItem.overview {
                        Text(overview)
                            .font(.system(size: 20))
                            .foregroundStyle(SashimiTheme.textSecondary)
                            .lineLimit(2)
                            .frame(maxWidth: 700, alignment: .leading)
                    }
                    
                    if items.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<items.count, id: \.self) { index in
                                Capsule()
                                    .fill(index == currentIndex ? SashimiTheme.accent : SashimiTheme.textTertiary)
                                    .frame(width: index == currentIndex ? 26 : 10, height: 4)
                                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 35)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(isFocused ? 0.6 : 0), lineWidth: 2)
            )
            .padding(.horizontal, 40)
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(PlainNoHighlightButtonStyle())
        .focused($isFocused)
        .onMoveCommand { direction in
            guard items.count > 1 else { return }
            switch direction {
            case .left:
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentIndex = (currentIndex - 1 + items.count) % items.count
                }
                startAutoScroll()
            case .right:
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentIndex = (currentIndex + 1) % items.count
                }
                startAutoScroll()
            default:
                break
            }
        }
        .onAppear {
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
    }
    
    private func formatRuntime(_ ticks: Int64) -> String {
        let seconds = ticks / 10_000_000
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func formatEpisodeInfo(_ item: BaseItemDto) -> String {
        let season = item.parentIndexNumber ?? 1
        let episode = item.indexNumber ?? 1
        return "S\(season) E\(episode) • \(item.name)"
    }
}

// MARK: - Recently Added Library Row
struct RecentlyAddedLibraryRow: View {
    let library: JellyfinLibrary
    let onSelect: (BaseItemDto) -> Void
    @State private var items: [BaseItemDto] = []
    
    private var sectionTitle: String {
        "Recently Added \(library.name)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(sectionTitle)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(SashimiTheme.textPrimary)
                .padding(.horizontal, 80)
            
            if items.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(SashimiTheme.accent)
                    Spacer()
                }
                .frame(height: 340)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        ForEach(items) { item in
                            MediaPosterButton(item: item, libraryType: library.collectionType) {
                                onSelect(item)
                            }
                        }
                    }
                    .padding(.horizontal, 80)
                    .padding(.vertical, 20)
                }
            }
        }
        .task {
            await loadItems()
        }
    }
    
    private func loadItems() async {
        do {
            let latestItems = try await JellyfinClient.shared.getLatestMedia(parentId: library.id, limit: 30)
            items = deduplicateBySeries(latestItems)
        } catch {
            print("Failed to load recently added items: \(error)")
        }
    }
    
    private func deduplicateBySeries(_ items: [BaseItemDto]) -> [BaseItemDto] {
        var seen = Set<String>()
        var result: [BaseItemDto] = []
        
        for item in items {
            let key = item.type == .episode ? (item.seriesId ?? item.id) : item.id
            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }
        
        return Array(result.prefix(20))
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            SashimiTheme.background.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(SashimiTheme.textTertiary.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(SashimiTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }
                
                Text("Loading your library...")
                    .font(.headline)
                    .foregroundStyle(SashimiTheme.textSecondary)
            }
        }
    }
}

#Preview {
    HomeView()
}
