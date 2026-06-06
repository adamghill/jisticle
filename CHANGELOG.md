## 0.4.0

- Switched to Neon + Tree-sitter to prevent the entire document from re-rendering during syntax highlighting on every keypress
- Added 2MB highlighting threshold to avoid initial load pauses on large files
- Handle truncated content for files that are bigger than 1MB
- Improved markdown preview
- Added debouncing for preview updates (50ms) and language changes (100ms)
- Misc UI improvements

## 0.3.0

- Markdown preview
- Only enable save button when content is changed

## 0.2.0

- Drag and drop file(s) from finder to add it to a gist
- Lock icon is now orange when gist is private

## 0.1.0

- GitHub login with device flow
- List, view, edit, and delete gists
- Syntax highlighting with CodeEditor (ZeeZide/Highlightr)
- Local caching of gists
- Keychain storage for tokens
