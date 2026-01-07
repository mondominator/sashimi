import Foundation
import AVKit
import AVFoundation
import Combine

struct AudioTrackOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let languageCode: String?
    let index: Int
}

struct SubtitleTrackOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let languageCode: String?
    let index: Int
    let isOffOption: Bool
}

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading = true
    @Published var error: Error?
    @Published var currentItem: BaseItemDto?
    @Published var errorMessage: String?
    @Published var attemptedURL: String?
    @Published var audioTracks: [AudioTrackOption] = []
    @Published var selectedAudioTrackId: String?
    @Published var subtitleTracks: [SubtitleTrackOption] = []
    @Published var selectedSubtitleTrackId: String?
    
    private var timeObserver: Any?
    private var progressReportTask: Task<Void, Never>?
    private var statusObserver: NSKeyValueObservation?
    private var errorObserver: NSKeyValueObservation?
    private let client = JellyfinClient.shared
    
    func loadMedia(item: BaseItemDto) async {
        currentItem = item
        isLoading = true
        error = nil
        errorMessage = nil
        
        do {
            let playbackInfo = try await client.getPlaybackInfo(itemId: item.id)
            
            guard let mediaSource = playbackInfo.mediaSources?.first else {
                throw PlayerError.noMediaSource
            }
            
            let url: URL?
            if let transcodingPath = mediaSource.transcodingUrl, !transcodingPath.isEmpty {
                url = await client.buildURL(path: transcodingPath)
                print("Using transcoding URL")
            } else if let directPath = mediaSource.directStreamUrl, !directPath.isEmpty {
                url = await client.buildURL(path: directPath)
                print("Using direct stream URL")
            } else {
                url = await client.getPlaybackURL(itemId: item.id, mediaSourceId: mediaSource.id, container: mediaSource.container)
                print("Using constructed URL")
            }
            
            guard let url else {
                throw PlayerError.noStreamURL
            }
            
            attemptedURL = url.absoluteString
            print("Playing URL: \(url.absoluteString)")

            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)

            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            
            errorObserver = playerItem.observe(\.status) { [weak self] item, _ in
                Task { @MainActor in
                    if item.status == .failed {
                        self?.errorMessage = item.error?.localizedDescription ?? "Unknown playback error"
                        self?.error = item.error
                        print("AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown")")
                    }
                }
            }
            
            player = AVPlayer(playerItem: playerItem)
            player?.volume = 1.0
            player?.isMuted = false

            statusObserver = player?.observe(\.status) { [weak self] player, _ in
                Task { @MainActor in
                    if player.status == .failed {
                        self?.errorMessage = player.error?.localizedDescription ?? "Player failed"
                        self?.error = player.error
                        print("AVPlayer failed: \(player.error?.localizedDescription ?? "unknown")")
                    }
                }
            }
            
            if let startTicks = item.userData?.playbackPositionTicks, startTicks > 0 {
                let startTime = CMTime(value: startTicks / 10000, timescale: 1000)
                await player?.seek(to: startTime)
            }
            
            try? await client.reportPlaybackStart(itemId: item.id, positionTicks: item.userData?.playbackPositionTicks ?? 0)
            
            startProgressReporting()
            
            isLoading = false
            player?.play()
        } catch {
            print("Playback error: \(error)")
            self.error = error
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func startProgressReporting() {
        progressReportTask?.cancel()
        progressReportTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await reportProgress()
            }
        }
    }
    
    private func reportProgress() async {
        guard let item = currentItem,
              let player,
              let currentTime = player.currentItem?.currentTime() else { return }
        
        let positionTicks = Int64(currentTime.seconds * 10_000_000)
        let isPaused = player.timeControlStatus == .paused
        
        try? await client.reportPlaybackProgress(itemId: item.id, positionTicks: positionTicks, isPaused: isPaused)
    }
    
    func stop() async {
        progressReportTask?.cancel()
        
        if let item = currentItem,
           let player,
           let currentTime = player.currentItem?.currentTime() {
            let positionTicks = Int64(currentTime.seconds * 10_000_000)
            try? await client.reportPlaybackStopped(itemId: item.id, positionTicks: positionTicks)
        }
        
        player?.pause()
        player = nil
        currentItem = nil
    }
    
    func loadAudioTracks() {
        guard let playerItem = player?.currentItem else { return }
        
        let audioGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        guard let options = audioGroup?.options else {
            audioTracks = []
            return
        }
        
        var tracks: [AudioTrackOption] = []
        for (index, option) in options.enumerated() {
            let locale = option.locale
            let displayName = option.displayName
            let langCode = locale?.languageCode
            
            tracks.append(AudioTrackOption(
                id: "\(index)",
                displayName: displayName,
                languageCode: langCode,
                index: index
            ))
        }
        
        audioTracks = tracks
        
        if let currentSelection = playerItem.currentMediaSelection.selectedMediaOption(in: audioGroup!),
           let currentIndex = options.firstIndex(of: currentSelection) {
            selectedAudioTrackId = "\(currentIndex)"
        }
    }
    
    func selectAudioTrack(_ track: AudioTrackOption) {
        guard let playerItem = player?.currentItem,
              let audioGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
              track.index < audioGroup.options.count else { return }

        let option = audioGroup.options[track.index]
        playerItem.select(option, in: audioGroup)
        selectedAudioTrackId = track.id
    }

    func loadSubtitleTracks() {
        guard let playerItem = player?.currentItem else { return }

        let subtitleGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)

        var tracks: [SubtitleTrackOption] = []

        // Add "Off" option first
        tracks.append(SubtitleTrackOption(
            id: "off",
            displayName: "Off",
            languageCode: nil,
            index: -1,
            isOffOption: true
        ))

        if let options = subtitleGroup?.options {
            for (index, option) in options.enumerated() {
                let locale = option.locale
                let displayName = option.displayName
                let langCode = locale?.languageCode

                tracks.append(SubtitleTrackOption(
                    id: "\(index)",
                    displayName: displayName,
                    languageCode: langCode,
                    index: index,
                    isOffOption: false
                ))
            }
        }

        subtitleTracks = tracks

        // Check current selection
        if let subtitleGroup,
           let currentSelection = playerItem.currentMediaSelection.selectedMediaOption(in: subtitleGroup),
           let options = subtitleGroup.options as? [AVMediaSelectionOption],
           let currentIndex = options.firstIndex(of: currentSelection) {
            selectedSubtitleTrackId = "\(currentIndex)"
        } else {
            selectedSubtitleTrackId = "off"
        }
    }

    func selectSubtitleTrack(_ track: SubtitleTrackOption) {
        guard let playerItem = player?.currentItem,
              let subtitleGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }

        if track.isOffOption {
            playerItem.select(nil, in: subtitleGroup)
            selectedSubtitleTrackId = "off"
        } else if track.index < subtitleGroup.options.count {
            let option = subtitleGroup.options[track.index]
            playerItem.select(option, in: subtitleGroup)
            selectedSubtitleTrackId = track.id
        }
    }

    func loadAllTracks() {
        loadAudioTracks()
        loadSubtitleTracks()
    }

    deinit {
        progressReportTask?.cancel()
    }
}

enum PlayerError: LocalizedError {
    case noMediaSource
    case noStreamURL
    
    var errorDescription: String? {
        switch self {
        case .noMediaSource:
            return "No playable media source found"
        case .noStreamURL:
            return "Could not generate stream URL"
        }
    }
}
