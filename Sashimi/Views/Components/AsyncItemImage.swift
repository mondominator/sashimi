import SwiftUI

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
