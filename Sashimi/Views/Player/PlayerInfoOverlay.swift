import SwiftUI
import AVFoundation
import Combine

struct PlayerInfoOverlay: View {
    let item: BaseItemDto
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isVisible: Bool
    var onSeek: ((Double) -> Void)?
    var onPlayPause: (() -> Void)?
    var onShowSubtitles: (() -> Void)?
    var onShowChapters: (() -> Void)?
    var onShowSpeed: (() -> Void)?
    var onShowQuality: (() -> Void)?
    var onUserInteraction: (() -> Void)?
    var onExit: (() -> Void)?

    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var didScrub = false
    
    @FocusState private var focusedControl: PlayerControl?
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var displayProgress: Double {
        guard duration > 0 else { return 0 }
        let time = (isScrubbing && didScrub) ? scrubTime : currentTime
        return time / duration
    }

    private var isPlaying: Bool {
        viewModel.player?.timeControlStatus == .playing
    }

    var body: some View {
        ZStack {
            // Gradient overlays
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 280)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.5), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
            }
            .allowsHitTesting(false)

            VStack {
                topInfoBar.padding(.top, 50).padding(.horizontal, 80)
                Spacer()
                bottomControls.padding(.bottom, 60).padding(.horizontal, 80)
            }
        }
        .onReceive(timer) { _ in
            updateTime()
        }
        .onAppear {
            updateTime()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedControl = .playPause
            }
        }
        .onExitCommand {
            onExit?()
        }
    }
    
    private func updateTime() {
        guard let player = viewModel.player else { return }
        
        if let d = player.currentItem?.duration, d.isNumeric, d.seconds > 0 {
            duration = d.seconds
        }
        
        if !isScrubbing || !didScrub {
            let time = player.currentTime().seconds
            if time.isFinite && time >= 0 {
                currentTime = time
            }
        }
    }

    private var topInfoBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                if let seriesName = item.seriesName {
                    Text(seriesName).font(.system(size: 30, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                }
                HStack(spacing: 16) {
                    Text(item.type == .episode ? item.name : item.displayTitle)
                        .font(.system(size: 48, weight: .bold)).foregroundStyle(.white).lineLimit(1)

                    if let season = item.parentIndexNumber, let episode = item.indexNumber {
                        Text(String(format: "S%d · E%d", season, episode))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(SashimiTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                HStack(spacing: 8) {
                    if let year = item.productionYear {
                        Text(String(year))
                    }
                    if let runtime = item.runTimeTicks {
                        let mins = Int(runtime / 600_000_000)
                        Text("•")
                        Text(mins >= 60 ? "\(mins/60)h \(mins%60)m" : "\(mins) min")
                    }
                    if let rating = item.officialRating {
                        Text("•")
                        Text(rating).padding(.horizontal, 8).padding(.vertical, 3)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    }
                    if let score = item.communityRating {
                        Text("•")
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                            Text(String(format: "%.1f", score))
                        }
                    }
                }.font(.system(size: 24, weight: .medium)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Scrub time indicator
            if didScrub {
                Text(formatTime(scrubTime))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(SashimiTheme.accent)
            }

            // Progress bar
            ProgressBarButton(
                progress: displayProgress,
                isFocused: focusedControl == .progressBar,
                chapters: item.chapters,
                totalTicks: item.runTimeTicks
            ) {
                // On select - confirm scrub and resume playback
                if didScrub {
                    onSeek?(scrubTime)
                    didScrub = false
                    isScrubbing = false
                    // Resume playback after seeking
                    if !isPlaying {
                        onPlayPause?()
                    }
                }
                onUserInteraction?()
            }
            .focused($focusedControl, equals: .progressBar)
            .onChange(of: focusedControl) { _, newFocus in
                if newFocus == .progressBar {
                    scrubTime = currentTime
                    isScrubbing = true
                    didScrub = false
                } else if isScrubbing {
                    // When leaving progress bar, seek if we scrubbed
                    if didScrub {
                        onSeek?(scrubTime)
                    }
                    isScrubbing = false
                    didScrub = false
                }
                onUserInteraction?()
            }
            .onMoveCommand { dir in
                guard focusedControl == .progressBar, duration > 0 else { return }
                let seekAmount: Double = 30
                if dir == .left {
                    scrubTime = max(0, scrubTime - seekAmount)
                    didScrub = true
                    onUserInteraction?()
                } else if dir == .right {
                    scrubTime = min(duration, scrubTime + seekAmount)
                    didScrub = true
                    onUserInteraction?()
                }
            }

            // Time labels
            HStack {
                Text(formatTime(currentTime)).font(.system(size: 22, weight: .medium, design: .monospaced)).foregroundStyle(.white)
                Spacer()
                Text("-" + formatTime(max(duration - currentTime, 0))).font(.system(size: 22, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
            }

            // Control buttons
            HStack(spacing: 32) {
                // Playback controls
                HStack(spacing: 20) {
                    TVControlButton(icon: "gobackward.10", isFocused: focusedControl == .rewind) {
                        onSeek?(max(0, currentTime - 10))
                        onUserInteraction?()
                    }
                    .focused($focusedControl, equals: .rewind)
                    
                    TVControlButton(icon: isPlaying ? "pause.fill" : "play.fill", size: 40, isFocused: focusedControl == .playPause) {
                        onPlayPause?()
                        onUserInteraction?()
                    }
                    .focused($focusedControl, equals: .playPause)
                    
                    TVControlButton(icon: "goforward.10", isFocused: focusedControl == .forward) {
                        if duration > 0 { onSeek?(min(duration, currentTime + 10)) }
                        onUserInteraction?()
                    }
                    .focused($focusedControl, equals: .forward)
                }

                Spacer()

                // Settings controls
                HStack(spacing: 16) {
                    TVControlButton(icon: "captions.bubble", highlight: viewModel.selectedSubtitleTrackId != "off", isFocused: focusedControl == .subtitles) {
                        onShowSubtitles?()
                    }
                    .focused($focusedControl, equals: .subtitles)
                    
                    if let chapters = item.chapters, !chapters.isEmpty {
                        TVControlButton(icon: "list.bullet", isFocused: focusedControl == .chapters) {
                            onShowChapters?()
                        }
                        .focused($focusedControl, equals: .chapters)
                    }
                    
                    TVControlButton(icon: "speedometer", isFocused: focusedControl == .speed) {
                        onShowSpeed?()
                    }
                    .focused($focusedControl, equals: .speed)
                    
                    if onShowQuality != nil {
                        TVControlButton(icon: "gearshape", isFocused: focusedControl == .quality) {
                            onShowQuality?()
                        }
                        .focused($focusedControl, equals: .quality)
                    }
                }
            }
        }
    }

    private func formatTime(_ s: Double) -> String {
        guard s.isFinite && s >= 0 else { return "0:00" }
        let t = Int(s), h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Progress Bar Button

struct ProgressBarButton: View {
    let progress: Double
    let isFocused: Bool
    let chapters: [ChapterInfo]?
    let totalTicks: Int64?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SashimiTheme.accent)
                        .frame(width: max(0, geo.size.width * CGFloat(min(max(progress, 0), 1))))

                    // Chapter markers
                    if let chapters = chapters, let totalTicks = totalTicks, totalTicks > 0 {
                        ForEach(chapters.dropFirst(), id: \.startPositionTicks) { ch in
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2, height: isFocused ? 18 : 12)
                                .offset(x: geo.size.width * CGFloat(Double(ch.startPositionTicks) / Double(totalTicks)) - 1)
                        }
                    }

                    // Scrub handle (only when focused)
                    if isFocused {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.5), radius: 3)
                            .offset(x: geo.size.width * CGFloat(progress) - 8)
                    }
                }
            }
            .frame(height: isFocused ? 10 : 6)
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(TVProgressBarStyle(isFocused: isFocused))
    }
}

struct TVProgressBarStyle: ButtonStyle {
    let isFocused: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - TV Control Button

struct TVControlButton: View {
    let icon: String
    var size: CGFloat = 28
    var highlight: Bool = false
    var isFocused: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(highlight ? SashimiTheme.accent : .white)
                .opacity(isFocused ? 1.0 : 0.8)
                .scaleEffect(isFocused ? 1.3 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isFocused)
        }
        .buttonStyle(TVControlButtonStyle())
    }
}

struct TVControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Player Control Enum

enum PlayerControl: Hashable {
    case progressBar
    case rewind
    case playPause
    case forward
    case subtitles
    case chapters
    case speed
    case quality
}

// Keep for compatibility
struct NoStyleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct ControlBtn: View {
    let icon: String
    var size: CGFloat = 28
    var highlight: Bool = false
    var isFocused: Bool = false
    let action: () -> Void

    var body: some View {
        TVControlButton(icon: icon, size: size, highlight: highlight, isFocused: isFocused, action: action)
    }
}
