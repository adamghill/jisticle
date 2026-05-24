# Jisticle

A native macOS GitHub Gist client built with SwiftUI.

## Features

- **GitHub Device Flow Authentication** - Secure, no client secret required
- **List & Browse Gists** - View all your gists in a searchable sidebar
- **Syntax Highlighting** - Full code editor with language detection
- **Edit Gists** - Modify files and save changes directly
- **Create New Gists** - Quick creation with public/secret toggle
- **Delete Gists** - Remove unwanted gists with confirmation
- **Three-Pane Layout** - Modern macOS NavigationSplitView design

## Requirements

- macOS 14.0+
- GitHub account

## Build from Source

```bash
# Clone the repository
git clone https://github.com/adamghill/jisticle.git
cd jisticle

# Install dependencies and build
swift package resolve
swift build

# Or use just (requires just to be installed)
just run
```

## Release Build

```bash
just build-release [version]
```

This creates `Jisticle-macOS.dmg` ready for distribution.

## Architecture

- **SwiftUI** - Modern declarative UI
- **CodeEditorView** - Syntax highlighting via TextKit 2
- **GitHub Device Flow** - Secure OAuth authentication
- **KeychainAccess** - Secure token storage
- **GistProvider Protocol** - Abstraction for future multi-provider support

## License

MIT License
