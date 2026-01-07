import SwiftUI
import AVKit
import Combine

struct PlayerView: View {
    let item: BaseItemDto

    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?
    @State private var showingAudioPicker = false
    @State private var showingSubtitlePicker = false

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
                // Video layer
                PlayerLayerView(player: player)
                    .ignoresSafeArea()

                // Controls overlay
                if showControls {
                    controlsOverlay(player: player)
                }
            }
        }
        .task {
            await viewModel.loadMedia(item: item)
            setupTimeObserver()
        }
        .onDisappear {
            if let observer = timeObserver, let player = viewModel.player {
                player.removeTimeObserver(observer)
            }
            Task {
                await viewModel.stop()
            }
        }
        .onExitCommand {
            if showControls {
                showControls = false
            } else {
                Task {
                    await viewModel.stop()
                    dismiss()
                }
            }
        }
        .onPlayPauseCommand {
            togglePlayPause()
        }
        .onMoveCommand { direction in
            if !showControls {
                showControlsTemporarily()
            } else {
                // Reset hide timer when navigating
                scheduleHideControls()
            }
        }
        .sheet(isPresented: $showingAudioPicker) {
            AudioPickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSubtitlePicker) {
            SubtitlePickerSheet(viewModel: viewModel)
        }
    }

    private func setupTimeObserver() {
        guard let player = viewModel.player else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
            if let item = player.currentItem {
                duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
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

    private func controlsOverlay(player: AVPlayer) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 30) {
                // Title
                Text(item.displayTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // Progress bar
                PlayerProgressBar(
                    currentTime: currentTime,
                    duration: duration,
                    onSeek: { newTime in
                        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1000))
                        scheduleHideControls()
                    }
                )

                // Time labels
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("-\(formatTime(duration - currentTime))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                // Control buttons
                HStack(spacing: 60) {
                    // Audio button
                    ControlButton(
                        icon: "speaker.wave.2",
                        label: "Audio"
                    ) {
                        viewModel.loadAllTracks()
                        showingAudioPicker = true
                    }

                    // Skip back
                    ControlButton(
                        icon: "gobackward.15",
                        label: ""
                    ) {
                        skip(by: -15, player: player)
                    }

                    // Play/Pause
                    ControlButton(
                        icon: player.timeControlStatus == .playing ? "pause.fill" : "play.fill",
                        label: "",
                        isLarge: true
                    ) {
                        togglePlayPause()
                    }

                    // Skip forward
                    ControlButton(
                        icon: "goforward.15",
                        label: ""
                    ) {
                        skip(by: 15, player: player)
                    }

                    // Subtitles button
                    ControlButton(
                        icon: "captions.bubble",
                        label: "Subtitles"
                    ) {
                        viewModel.loadAllTracks()
                        showingSubtitlePicker = true
                    }
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 60)
            .padding(.top, 40)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8), .black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: showControls)
    }

    private func togglePlayPause() {
        guard let player = viewModel.player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            showControlsTemporarily()
        } else {
            player.play()
            scheduleHideControls()
        }
    }

    private func skip(by seconds: Double, player: AVPlayer) {
        let newTime = max(0, min(currentTime + seconds, duration))
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1000))
        scheduleHideControls()
    }

    private func showControlsTemporarily() {
        showControls = true
        scheduleHideControls()
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled && viewModel.player?.timeControlStatus == .playing {
                await MainActor.run {
                    showControls = false
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
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
        layer as! AVPlayerLayer
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

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.card)
        .focused($isFocused)
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
                Button(action: {
                    viewModel.selectAudioTrack(track)
                    dismiss()
                }) {
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
                Button(action: {
                    viewModel.selectSubtitleTrack(track)
                    dismiss()
                }) {
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
