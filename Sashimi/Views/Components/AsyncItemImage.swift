import SwiftUI

// Smart poster that tries multiple item IDs until one works
struct SmartPosterImage: View {
    let itemIds: [String]
    let maxWidth: Int

    @State private var currentIndex: Int = 0
    @State private var imageURL: URL?
    @State private var loadFailed: Bool = false

    var body: some View {
        Group {
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.clear.onAppear {
                            tryNextItemId()
                        }
                    case .empty:
                        Rectangle()
                            .fill(.gray.opacity(0.2))
                            .overlay { ProgressView() }
                    @unknown default:
                        placeholderView
                    }
                }
            } else if loadFailed {
                placeholderView
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.2))
                    .overlay { ProgressView() }
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard currentIndex < itemIds.count else {
            loadFailed = true
            return
        }

        // Try Primary first, then Thumb for current item
        let itemId = itemIds[currentIndex]
        if let url = await JellyfinClient.shared.imageURL(itemId: itemId, imageType: "Primary", maxWidth: maxWidth) {
            imageURL = url
        } else if let url = await JellyfinClient.shared.imageURL(itemId: itemId, imageType: "Thumb", maxWidth: maxWidth) {
            imageURL = url
        } else {
            tryNextItemId()
        }
    }

    private func tryNextItemId() {
        currentIndex += 1
        if currentIndex < itemIds.count {
            Task {
                await loadImage()
            }
        } else {
            loadFailed = true
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.gray)
            }
    }
}

struct AsyncItemImage: View {
    let itemId: String
    let imageType: String
    let maxWidth: Int
    var contentMode: ContentMode = .fill
    var fallbackImageTypes: [String] = []

    @State private var imageURL: URL?
    @State private var currentTypeIndex: Int = 0
    @State private var loadFailed: Bool = false

    private var allImageTypes: [String] {
        [imageType] + fallbackImageTypes
    }

    var body: some View {
        Group {
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        if currentTypeIndex < allImageTypes.count - 1 {
                            // Try next fallback
                            Color.clear.onAppear {
                                tryNextFallback()
                            }
                        } else {
                            placeholderView
                        }
                    case .empty:
                        Rectangle()
                            .fill(.gray.opacity(0.2))
                            .overlay {
                                ProgressView()
                            }
                    @unknown default:
                        placeholderView
                    }
                }
            } else if loadFailed {
                placeholderView
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.2))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        imageURL = await JellyfinClient.shared.imageURL(itemId: itemId, imageType: allImageTypes[currentTypeIndex], maxWidth: maxWidth)
        if imageURL == nil && currentTypeIndex < allImageTypes.count - 1 {
            tryNextFallback()
        } else if imageURL == nil {
            loadFailed = true
        }
    }

    private func tryNextFallback() {
        currentTypeIndex += 1
        if currentTypeIndex < allImageTypes.count {
            Task {
                imageURL = await JellyfinClient.shared.imageURL(itemId: itemId, imageType: allImageTypes[currentTypeIndex], maxWidth: maxWidth)
                if imageURL == nil && currentTypeIndex >= allImageTypes.count - 1 {
                    loadFailed = true
                }
            }
        } else {
            loadFailed = true
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.gray)
            }
    }
}
