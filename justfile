# List commands
_default:
    just --list --unsorted --justfile {{ justfile() }} --list-heading $'Available commands:\n'

# Build the application in release mode and package it into a .app bundle
build-release version="":
    ./scripts/build-release.sh "{{version}}"

# Regenerate AppIcon.icns from AppIcon.png
generate-icon:
    ./scripts/generate-icon.sh

test:
    swift test

run:
    swift build && open .build/debug/Jisticle
