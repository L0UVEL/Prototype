#!/bin/bash
set -ex  # Exit on error and print each command

echo "Current Directory: $(pwd)"
ls -la

# 1. Download the Flutter SDK
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# 2. Set the Flutter path
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. Check Flutter version and config
echo "Checking Flutter version..."
flutter --version

echo "Enabling Web..."
flutter config --enable-web

# 4. Build the web version
echo "Running pub get..."
flutter pub get

echo "Building Web..."
flutter build web --web-renderer html --release

echo "Build complete."
