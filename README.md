# Sashimi

<p align="center">
  <img src="sashimi-logo.png" alt="Sashimi Logo" width="200">
</p>

<p align="center">
  <strong>A native tvOS client for Jellyfin media servers</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#development">Development</a> •
  <a href="#contributing">Contributing</a>
</p>

---

## Features

- Native SwiftUI interface designed for Apple TV
- Browse and stream your Jellyfin media library
- Support for movies, TV shows, and YouTube-style content
- Continue watching with playback progress sync
- Top Shelf integration for quick access to recent content
- Secure credential storage using Keychain

## Requirements

- tvOS 17.0+
- Jellyfin server (local or remote)
- Xcode 15.0+ (for development)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/mondominator/sashimi.git
   cd sashimi
   ```

2. Run the setup script:
   ```bash
   ./scripts/setup.sh
   ```

3. Open `Sashimi.xcodeproj` in Xcode

4. Select your development team in Signing & Capabilities

5. Build and run on Apple TV Simulator or device

### Dependencies

- [Nuke](https://github.com/kean/Nuke) - Image loading and caching

## Development

### Project Structure

```
Sashimi/
├── App/              # App entry point
├── Services/         # API client, session management
├── ViewModels/       # MVVM view models
├── Views/            # SwiftUI views
│   ├── Home/         # Home screen
│   ├── Auth/         # Login/server connection
│   ├── Library/      # Media library browsing
│   ├── Detail/       # Media detail views
│   ├── Player/       # Video player
│   └── Components/   # Reusable UI components
├── Models/           # Data models
└── Resources/        # Assets
```

### Build Commands

```bash
# Generate Xcode project (requires XcodeGen)
xcodegen generate

# Build with xcodebuild
xcodebuild -project Sashimi.xcodeproj -scheme Sashimi -destination 'platform=tvOS Simulator,name=Apple TV'

# Build with Swift Package Manager
swift build
```

### Git Hooks

This project uses git hooks for code quality. After cloning, run:

```bash
git config core.hooksPath .githooks
```

Or use the setup script which configures this automatically.

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Commit using conventional commits: `git commit -m "feat: add new feature"`
4. Push to your fork: `git push origin feat/my-feature`
5. Open a Pull Request

### Commit Message Format

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Code style changes
- `refactor:` - Code refactoring
- `test:` - Test updates
- `chore:` - Maintenance tasks

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Jellyfin](https://jellyfin.org/) - The free software media system
- [Nuke](https://github.com/kean/Nuke) - Image loading framework
