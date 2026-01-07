import SwiftUI

private enum SashimiTheme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let cardBackground = Color(white: 0.12)
    static let accent = Color(red: 0.36, green: 0.68, blue: 0.90)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textTertiary = Color(white: 0.45)
    static let focusGlow = Color(red: 0.36, green: 0.68, blue: 0.90).opacity(0.5)
}

struct MediaRow: View {
    let title: String
    var subtitle: String?
    let items: [BaseItemDto]
    let onSelect: (BaseItemDto) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(SashimiTheme.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 18))
                        .foregroundStyle(SashimiTheme.textTertiary)
                }
            }
            .padding(.horizontal, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 36) {
                    ForEach(items) { item in
                        MediaPosterButton(item: item) {
                            onSelect(item)
                        }
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 20)
            }
        }
    }
}

struct MediaPosterButton: View {
    let item: BaseItemDto
    var libraryType: String?
    var libraryName: String?
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    // Detect YouTube-style content by library name or characteristics
    private var isYouTubeStyle: Bool {
        // Check library name for YouTube
        if let name = libraryName?.lowercased(), name.contains("youtube") {
            return true
        }
        // Check library type for homevideos
        if libraryType?.lowercased() == "homevideos" {
            return true
        }
        // For episodes without parent backdrops (legacy check)
        if item.type == .episode {
            let parentHasBackdrop = item.parentBackdropImageTags?.isEmpty == false
            if !parentHasBackdrop {
                return true
            }
        }
        return false
    }

    private var displayTitle: String {
        switch item.type {
        case .movie:
            return item.name
        case .series:
            return item.name
        case .episode:
            return item.seriesName ?? item.name
        default:
            return item.name
        }
    }

    // Check if item has its own primary image
    private var itemHasPrimaryImage: Bool {
        if let tags = item.imageTags, tags["Primary"] != nil {
            return true
        }
        return false
    }

    private var imageId: String {
        if item.type == .episode || item.type == .video {
            // For YouTube-style: use series poster (seasons don't have images)
            if isYouTubeStyle {
                return item.seriesId ?? item.id
            }
            // Use season poster for regular TV shows, fall back to series
            return item.seasonId ?? item.seriesId ?? item.id
        }
        return item.id
    }

    private var fallbackImageTypes: [String] {
        if isYouTubeStyle {
            // YouTube-style content may have Thumb instead of Primary
            return ["Thumb", "Backdrop"]
        }
        return ["Thumb"]
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    AsyncItemImage(
                        itemId: imageId,
                        imageType: "Primary",
                        maxWidth: 400,
                        fallbackImageTypes: fallbackImageTypes
                    )
                    .frame(width: 220, height: 330)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.6)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let rating = item.communityRating, rating > 0 {
                        HStack(spacing: 4) {
                            Image("TMDBLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 18)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(10)
                    }

                    if item.userData?.played == true {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                    .background(
                                        Circle()
                                            .fill(.black.opacity(0.5))
                                            .padding(-2)
                                    )
                                    .padding(10)
                            }
                            Spacer()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(isFocused ? 0.6 : 0), lineWidth: 2)
                )

                VStack(alignment: .leading, spacing: 4) {
                    MarqueeText(
                        text: displayTitle,
                        isScrolling: isFocused
                    )
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(SashimiTheme.textPrimary)

                    if !isYouTubeStyle, let year = item.productionYear {
                        Text(String(year))
                            .font(.system(size: 16))
                            .foregroundStyle(SashimiTheme.textTertiary)
                    }
                }
                .frame(width: 220, alignment: .leading)
            }
            .scaleEffect(isFocused ? 1.10 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(PlainNoHighlightButtonStyle())
        .focused($isFocused)
    }
}

struct PlainNoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct MarqueeText: View {
    let text: String
    let isScrolling: Bool
    var height: CGFloat = 28

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let needsScroll = textWidth > geo.size.width

            Text(text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(GeometryReader { textGeo in
                    Color.clear.onAppear {
                        textWidth = textGeo.size.width
                        containerWidth = geo.size.width
                    }
                })
                .offset(x: needsScroll && isScrolling ? offset : 0)
                .onChange(of: isScrolling) { _, scrolling in
                    if scrolling && needsScroll {
                        withAnimation(.linear(duration: Double(textWidth - containerWidth) / 30).delay(0.5)) {
                            offset = -(textWidth - containerWidth + 20)
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            offset = 0
                        }
                    }
                }
        }
        .frame(height: height)
        .clipped()
    }
}
