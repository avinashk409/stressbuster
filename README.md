# StressBuster - Mental Health Counseling App

A Flutter-based mobile application for mental health counseling and support.

## Features

- User authentication and profile management
- Real-time chat with counselors
- Video counseling sessions
- Wallet management and payments
- Appointment scheduling
- Push notifications
- Offline support

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode
- Firebase account
- Cashfree account for payments

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/stressbuster.git
   cd stressbuster
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project
   - Add Android and iOS apps
   - Download and add configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS
   - Enable Authentication, Firestore, Storage, and Cloud Messaging

4. **Configure Environment Variables**
   - Copy `.env.example` to `.env`
   - Update the values with your configuration:
     - Firebase credentials
     - Cashfree credentials
     - API endpoints

5. **Configure Signing**
   - Android:
     ```bash
     keytool -genkey -v -keystore android/app/keystore/release.keystore -alias your-key-alias -keyalg RSA -keysize 2048 -validity 10000
     ```
   - iOS: Configure signing in Xcode

## Building for Production

### Android

1. **Generate Release Build**
   ```bash
   flutter build appbundle
   ```

2. **Sign the APK**
   ```bash
   flutter build apk --release
   ```

### iOS

1. **Configure in Xcode**
   - Open `ios/Runner.xcworkspace`
   - Set up signing certificates
   - Configure provisioning profiles

2. **Build Archive**
   ```bash
   flutter build ios --release
   ```

## Deployment

### Android

1. **Google Play Store**
   - Create a new release in Google Play Console
   - Upload the app bundle
   - Complete store listing
   - Submit for review

### iOS

1. **App Store**
   - Create a new app in App Store Connect
   - Upload the build through Xcode
   - Complete store listing
   - Submit for review

## Security Considerations

- All API keys and secrets are stored in environment variables
- Firebase security rules are configured for data protection
- SSL pinning is implemented for API calls
- Sensitive data is encrypted at rest

## Monitoring and Analytics

- Firebase Analytics for user behavior tracking
- Firebase Crashlytics for crash reporting
- Custom logging for debugging

## Support

For support, email support@stressbuster.com or create an issue in the repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
