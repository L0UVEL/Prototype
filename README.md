# Mobile Health Support With AI 

A Mobile Based Health Support System with an AI Chatbot using Flutter/Dart.

## Features

- **User & Student Roles**: Personalized health tracking and AI chatbot support.
- **Admin Role**: Manage platform announcements and user oversight.
- **AI Chatbot**: Intelligent health support powered by Google Generative AI.
- **Health Tracking**: Regular check-ins and health profile management.
- **Push Notifications**: Local and push notifications for reminders and announcements.
- **Authentication**: Secure login and registration using Firebase Auth.

## Tech Stack

- **Frontend**: Flutter / Dart
- **Backend & Cloud**: Firebase (Auth, Firestore, Storage, Messaging)
- **AI Integration**: Google Generative AI (Gemini)
- **State Management**: Provider
- **Routing**: GoRouter

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- An emulator or physical device connected.
- Firebase CLI configured for your project.

### Installation

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Configure Environment**:
    - Add a `.env` file in the root directory for API keys (e.g., Gemini API Key).
    - Make sure your Firebase configuration files (`google-services.json` / `GoogleService-Info.plist`) are set up for Android/iOS.

### Running the App

Run the following command in your terminal:

```bash
flutter run
```

To run on a specific device, use:

```bash
flutter run -d <device-id>
```

## Project Structure

- `lib/config/`: App configuration, routing, and theme settings.
- `lib/core/`: Core services (AI, Auth, Notifications) and generic models.
- `lib/features/`: Feature modules (Admin, Auth, Chat, Health, Home, Student, Shared).
- `lib/main.dart`: Entry point of the application.

## Group Members
Louvel Rouz M. Hernandez\
Mark Nerant M. Naca\
Roxane G. Pionilla\
Erica Mae B. Recaña\
Vence M. Santiago
