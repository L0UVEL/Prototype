#!/bin/bash
set -ex

# 1. Download the Flutter SDK
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# 2. Set the Flutter path
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. Disable warnings and enable web
export BOT=true
flutter config --enable-web

# 4. Pre-download web artifacts
flutter precache --web

# 5. Create .env file from Vercel Environment Variables if missing
if [ ! -f ".env" ]; then
  echo "Creating .env from environment variables..."
  echo "GEMINI_API_KEY=$GEMINI_API_KEY" > .env
  echo "SMTP_USERNAME=$SMTP_USERNAME" >> .env
  echo "SMTP_PASSWORD=$SMTP_PASSWORD" >> .env
  echo "SMTP_SERVER=$SMTP_SERVER" >> .env
  echo "SMTP_PORT=$SMTP_PORT" >> .env
fi

# 6. Install dependencies and generate code
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# 7. Build the web version
flutter build web --release

# 8. Move build output to 'public' folder (what Vercel expects)
echo "Moving build output to public/ folder..."
mkdir -p public
cp -r build/web/* public/

echo "Build complete."
