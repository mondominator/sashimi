# App Store Screenshots

Place your tvOS screenshots in the `en-US/` folder (or other locale folders as needed).

## Required Sizes

For tvOS apps, you need screenshots in these sizes:

| Device | Resolution | Required |
|--------|------------|----------|
| Apple TV HD | 1920 x 1080 | Yes |
| Apple TV 4K | 3840 x 2160 | Recommended |

## Screenshot Guidelines

1. **Minimum**: 1 screenshot required
2. **Maximum**: 10 screenshots allowed
3. **Format**: PNG or JPEG
4. **No alpha**: Screenshots cannot have transparency

## Naming Convention

Use this naming pattern for automatic ordering:

```
01_home_screen.png
02_library_browse.png
03_movie_detail.png
04_video_playback.png
05_search.png
```

## Taking Screenshots

### Using Xcode Simulator

1. Run app in tvOS Simulator
2. Navigate to desired screen
3. Press `Cmd + S` to save screenshot
4. Screenshots save to Desktop by default

### Using fastlane snapshot (Advanced)

For automated screenshot capture, see:
https://docs.fastlane.tools/actions/snapshot/

## Tips

- Show actual content, not placeholder data
- Highlight key features
- First screenshot is most important (used as preview)
- Consider adding text overlays to explain features
