# Building NotifyMeHow

## Prerequisites

- macOS 26 (Tahoe) — other versions untested
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Install

```bash
# Clone the repository
git clone https://github.com/mbinde/NotifyMeHow.git
cd NotifyMeHow

# Build and create app bundle
./create-app.sh

# Install to Applications (optional)
cp -r NotifyMeHow.app /Applications/
```

## Running

```bash
# From the build directory
open NotifyMeHow.app

# Or if installed
open /Applications/NotifyMeHow.app
```

On first launch, macOS will prompt for Accessibility permissions. Grant access in **System Settings > Privacy & Security > Accessibility**.

## CLI Mode

The app also supports command-line usage for scripting:

```bash
.build/debug/NotifyMeHow --help
```

## Development

```bash
# Build only (no app bundle)
swift build

# Run tests
swift test

# Build release version
swift build -c release
```

## Creating a Release

To create a signed, notarized release for distribution:

```bash
./release.sh
```

This requires a Developer ID Application certificate and notarization credentials stored in your Keychain. See the comments in `release.sh` for setup instructions. The script produces `release/NotifyMeHow.zip` ready for upload to GitHub Releases.
