#!/bin/sh
set -e

# Hottoshita.xcodeproj is gitignored — xcodegen regenerates it from
# project.yml locally, so it never lands in the repo Xcode Cloud clones.
# Run that generation step here, before Xcode Cloud tries to build it.

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
