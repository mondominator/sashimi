import SwiftUI

// Smart poster that tries multiple item IDs until one works
// For each item ID, tries Primary then Thumb image types
struct SmartPosterImage: View {
    let itemIds: [String]
    let maxWidth: Int

    @State private var currentIndex: Int = 0
    @State private var currentImageType: String = "Primary"
    @State private var loadFailed: Bool = false
    @State private var attemptId = UUID()

    private var currentURL: URL? {
        guard currentIndex < itemIds.count else { return nil }
        return JellyfinClient.shared.syncImageURL(
            itemId: itemIds[currentIndex],
            imageType: currentImageType,
            maxWidth: maxWidth
        )
    }

    var body: some View {
        Group {
            if loadFailed {
                placeholderView
            } else if let url = currentURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.clear
                            .task(id: attemptId) {
                                advanceToNext()
                            }
                    case .empty:
                        Rectangle()
                            .fill(.gray.opacity(0.2))
                            .overlay { ProgressView() }
                    @unknown default:
                        placeholderView
                    }
                }
                .id("\(currentIndex)-\(currentImageType)-\(attemptId)")
            } else {
                placeholderView
            }
        }
    }

    private func advanceToNext() {
        // First try Thumb for current item if we were on Primary
        if currentImageType == "Primary" {
            currentImageType = "Thumb"
            attemptId = UUID()
            return
        }

        // Move to next item ID, reset to Primary
        if currentIndex < itemIds.count - 1 {
            currentIndex += 1
            currentImageType = "Primary"
            attemptId = UUID()
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

    @State private var currentTypeIndex: Int = 0
    @State private var loadFailed: Bool = false
    @State private var attemptId = UUID()

    private var allImageTypes: [String] {
        [imageType] + fallbackImageTypes
    }

    private var currentURL: URL? {
        guard currentTypeIndex < allImageTypes.count else { return nil }
        return JellyfinClient.shared.syncImageURL(
            itemId: itemId,
            imageType: allImageTypes[currentTypeIndex],
            maxWidth: maxWidth
        )
    }

    var body: some View {
        Group {
            if loadFailed {
                placeholderView
            } else if let url = currentURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        Color.clear
                            .task(id: attemptId) {
                                advanceToNextType()
                            }
                    case .empty:
                        Rectangle()
                            .fill(.gray.opacity(0.2))
                            .overlay { ProgressView() }
                    @unknown default:
                        placeholderView
                    }
                }
                .id("\(currentTypeIndex)-\(attemptId)")
            } else {
                placeholderView
            }
        }
    }

    private func advanceToNextType() {
        if currentTypeIndex < allImageTypes.count - 1 {
            currentTypeIndex += 1
            attemptId = UUID()
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
