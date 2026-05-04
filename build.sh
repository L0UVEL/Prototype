#!/bin/bash
set -ex

# 1. Download the Flutter SDK (shallow clone for speed)
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# 2. Set the Flutter path
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. Disable the "running as root" warning and enable web
export BOT=true
flutter config --enable-web

# 4. Pre-download web artifacts
flutter precache --web

# 5. Build the web version
# Using standard release build (renderer defaults to 'auto')
flutter pub get
flutter build web --release

echo "Build complete."
