# App Store Deployment Guide

This guide covers deploying Sashimi to the tvOS App Store.

## Prerequisites

1. **Apple Developer Account** - Enrolled in Apple Developer Program ($99/year)
2. **App Store Connect** - Access to create and manage apps
3. **Xcode** - Latest stable version
4. **Signing Certificates** - Distribution certificate and provisioning profiles

## App Store Connect Setup

### 1. Create App Record

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Go to **My Apps** → **+** → **New App**
3. Fill in:
   - Platform: tvOS
   - Name: Sashimi
   - Primary Language: English (U.S.)
   - Bundle ID: `com.sashimi.app`
   - SKU: `sashimi-tvos`

### 2. App Information

Fill out required metadata:

- **Category**: Entertainment
- **Content Rights**: Does not contain third-party content
- **Age Rating**: Complete questionnaire (likely 4+)

### 3. Pricing and Availability

- **Price**: Free
- **Availability**: All territories (or select specific)

## Certificates and Profiles

### Distribution Certificate

1. In Xcode: **Settings** → **Accounts** → Select Team
2. Click **Manage Certificates**
3. Create **Apple Distribution** certificate if needed

### App Store Provisioning Profile

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/profiles)
2. Create new profile:
   - Type: **tvOS App Store**
   - App ID: `com.sashimi.app`
   - Certificate: Your distribution certificate
3. Download and install in Xcode

### TopShelf Extension Profile

Create a separate profile for the TopShelf extension:
- App ID: `com.sashimi.app.topshelf`

## Build for Distribution

### 1. Update Version Numbers

In `project.yml`:
```yaml
settings:
  MARKETING_VERSION: 1.0.0
  CURRENT_PROJECT_VERSION: 1
```

Increment `CURRENT_PROJECT_VERSION` for each build.

### 2. Archive Build

```bash
# Generate fresh Xcode project
xcodegen generate

# Create archive
xcodebuild archive \
  -project Sashimi.xcodeproj \
  -scheme Sashimi \
  -destination 'generic/platform=tvOS' \
  -archivePath build/Sashimi.xcarchive
```

Or use Xcode: **Product** → **Archive**

### 3. Export for App Store

1. Open **Window** → **Organizer** in Xcode
2. Select the archive
3. Click **Distribute App**
4. Select **App Store Connect**
5. Choose **Upload** or **Export**
6. Follow prompts to sign and upload

## App Store Submission

### Required Assets

#### App Icon
- 1280×768 px (Large)
- 400×240 px (Small)
- Top Shelf: 1920×720 px (Wide), 2320×720 px (Wide Extended)

#### Screenshots
- 1920×1080 px (Apple TV HD)
- 3840×2160 px (Apple TV 4K)

Minimum 1 screenshot required, up to 10.

### App Review Information

Provide:
- Demo account credentials (for testing against Jellyfin)
- Notes explaining the app requires a Jellyfin server

### Review Guidelines Considerations

- **4.2.2** - App must be complete and functional
- **2.1** - App must work as described
- Explain Jellyfin server requirement in app description

## Automated Deployment (Optional)

### Fastlane Setup

Install Fastlane:
```bash
gem install fastlane
```

Initialize in project:
```bash
fastlane init
```

Example `Fastfile`:
```ruby
default_platform(:tvos)

platform :tvos do
  desc "Build and upload to TestFlight"
  lane :beta do
    increment_build_number
    build_app(
      scheme: "Sashimi",
      export_method: "app-store"
    )
    upload_to_testflight
  end

  desc "Deploy to App Store"
  lane :release do
    build_app(
      scheme: "Sashimi",
      export_method: "app-store"
    )
    upload_to_app_store
  end
end
```

## TestFlight

Before full release, use TestFlight for beta testing:

1. Upload build to App Store Connect
2. In TestFlight tab, add internal/external testers
3. Submit for Beta App Review (external testers only)
4. Distribute to testers

## Post-Release

### Monitoring

- Check **App Analytics** in App Store Connect
- Monitor crash reports in Xcode Organizer
- Respond to user reviews

### Updates

1. Increment version numbers
2. Create new archive
3. Upload to App Store Connect
4. Submit for review

## Troubleshooting

### Code Signing Issues

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Refresh provisioning profiles
xcodebuild -downloadAllPlatforms
```

### Upload Failures

- Ensure bundle IDs match profiles
- Check certificate expiration
- Verify team membership
