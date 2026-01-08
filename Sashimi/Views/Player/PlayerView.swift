import SwiftUI
import AVKit
import Combine

struct PlayerView: View {
    let item: BaseItemDto

    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading \(item.displayTitle)...")
                        .font(.headline)
                }
            } else if let error = viewModel.error ?? (viewModel.errorMessage != nil ? PlayerError.noStreamURL : nil) {
                errorView(error: error)
            } else if let player = viewModel.player {
                // Native VideoPlayer with built-in tvOS controls
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
        }
        .task {
            await viewModel.loadMedia(item: item)
        }
        .onDisappear {
            Task {
                await viewModel.stop()
            }
        }
        .onExitCommand {
            Task {
                await viewModel.stop()
                dismiss()
            }
        }
        .onChange(of: viewModel.playbackEnded) { _, ended in
            if ended {
                dismiss()
            }
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Playback Error")
                .font(.title2)

            Text(viewModel.errorMessage ?? error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Dismiss") {
                Task {
                    await viewModel.stop()
                    dismiss()
                }
            }
        }
    }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

class PlayerUIView: UIView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer  // Safe: layerClass returns AVPlayerLayer.self
    }

    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    var isLarge: Bool = false
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: isLarge ? 44 : 28))
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
            }
        }
        .frame(width: isLarge ? 100 : 80, height: isLarge ? 100 : 80)
        .background(isFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
        .clipShape(Circle())
        .scaleEffect(isFocused ? 1.15 : 1.0)
        .animation(.spring(response: 0.3), value: isFocused)
        .focusable(true) { _ in
            // Focus changed
        }
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            if !pressing {
                action()
            }
        }, perform: {})
    }
}

struct PlayerProgressBar: View {
    let currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @FocusState private var isFocused: Bool
    @State private var scrubPosition: Double?

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return (scrubPosition ?? currentTime) / duration
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: isFocused ? 12 : 6)
        .animation(.spring(response: 0.3), value: isFocused)
        .focused($isFocused)
    }
}

struct AudioPickerSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.audioTracks) { track in
                Button {
                    viewModel.selectAudioTrack(track)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.displayName)
                                .font(.headline)
                            if let lang = track.languageCode {
                                Text(lang.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if track.id == viewModel.selectedAudioTrackId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Audio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SubtitlePickerSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.subtitleTracks) { track in
                Button {
                    viewModel.selectSubtitleTrack(track)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.displayName)
                                .font(.headline)
                            if let lang = track.languageCode {
                                Text(lang.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if track.id == viewModel.selectedSubtitleTrackId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Subtitles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PlayerView(item: BaseItemDto(
        id: "test",
        name: "Test Movie",
        type: .movie,
        seriesName: nil,
        seriesId: nil,
        seasonId: nil,
        indexNumber: nil,
        parentIndexNumber: nil,
        overview: nil,
        runTimeTicks: nil,
        userData: nil,
        imageTags: nil,
        backdropImageTags: nil,
        parentBackdropImageTags: nil,
        primaryImageAspectRatio: nil,
        mediaType: nil,
        productionYear: nil,
        communityRating: nil,
        officialRating: nil,
        genres: nil,
        taglines: nil,
        people: nil,
        criticRating: nil,
        premiereDate: nil
    ))
}
