# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sashimi is a tvOS client for Jellyfin media servers, built with SwiftUI. It targets tvOS 17+ and uses Swift 5.9.

## Build Commands

```bash
# Build with Swift Package Manager
swift build

# Build with Xcode (uses project.yml with XcodeGen)
xcodebuild -project Sashimi.xcodeproj -scheme Sashimi -destination 'platform=tvOS Simulator,name=Apple TV'

# Generate Xcode project from project.yml (requires XcodeGen)
xcodegen generate
```

## Architecture

### MVVM Pattern
- **Views** (`Sashimi/Views/`): SwiftUI views organized by feature (Home, Auth, Library, Detail, Player, Components)
- **ViewModels** (`Sashimi/ViewModels/`): `@MainActor` `ObservableObject` classes managing view state
- **Models** (`Sashimi/Models/`): Codable DTOs matching Jellyfin API responses

### Core Services
- **JellyfinClient** (`Services/JellyfinClient.swift`): Swift `actor` handling all Jellyfin REST API communication. Singleton accessed via `JellyfinClient.shared`. Manages authentication headers, device identification, and playback URL generation.
- **SessionManager** (`Services/SessionManager.swift`): `@MainActor` `ObservableObject` singleton managing auth state, token persistence via UserDefaults, and session restoration.

### Data Flow
1. App entry (`SashimiApp.swift`) injects `SessionManager` as `@EnvironmentObject`
2. `ContentView` shows `ServerConnectionView` or `MainTabView` based on `sessionManager.isAuthenticated`
3. Views create their own `@StateObject` ViewModels which call `JellyfinClient.shared` methods
4. API responses are decoded into `BaseItemDto` and related model types

### Key Model Types
- `BaseItemDto`: Universal media item (movies, series, episodes, seasons)
- `ItemType`: Enum distinguishing media types
- `MediaSourceInfo`/`MediaStream`: Playback stream metadata
- `PlaybackInfoResponse`: Contains transcoding URLs and direct play options

### Video Playback
`PlayerViewModel` handles playback via AVKit:
- Fetches `PlaybackInfoResponse` to determine best stream URL (transcoding vs direct)
- Reports playback progress to Jellyfin server every 10 seconds
- Supports resume from last position via `userData.playbackPositionTicks`

### Dependencies
- **Nuke/NukeUI**: Image loading and caching (via SPM)
