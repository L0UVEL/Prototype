#!/bin/bash

# 1. Download the Flutter SDK
if [ ! -d "flutter" ]; then
  echo "Downloading Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# 2. Add Flutter to the Path
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Enable Web support and Build
flutter config --enable-web
flutter build web --release --web-renderer html

# 4. Clean up (Optional, helps keep the build size smaller)
# rm -rf flutter
