# SheTorque Hub

Intelligent rider safety, telematics, and safe routing platform for two-wheeler motorcyclists.

## Run

To run the application with your local environment secrets:

1. Copy `env.example.json` to `env.json` and provide your configuration values:
   ```bash
   cp env.example.json env.json
   ```

2. Launch the application targeting an Android device or emulator:
   ```bash
   flutter run --dart-define-from-file=env.json
   ```

## Getting Started

This application is built for Android mobile deployment.

- Target platform: Android API 21+
- Framework: Flutter SDK ≥ 3.11.5
