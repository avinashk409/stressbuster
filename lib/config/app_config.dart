class AppConfig {
  // API Configuration
  static const String apiBaseUrl = 'https://api.stressbuster.com';
  static const int apiTimeout = 30000; // 30 seconds
  
  // Payment Configuration
  static const String cashfreeAppId = 'YOUR_CASHFREE_APP_ID';
  static const String cashfreeSecretKey = 'YOUR_CASHFREE_SECRET_KEY';
  static const bool isProduction = true;
  
  // Cache Configuration
  static const int cacheDuration = 3600; // 1 hour
  static const int maxCacheSize = 100; // MB
  
  // Feature Flags
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const int splashScreenDuration = 2000; // 2 seconds
  
  // Validation Rules
  static const int minPasswordLength = 8;
  static const int maxMessageLength = 1000;
  static const int maxAppointmentDuration = 120; // minutes
  
  // Rate Limiting
  static const int maxLoginAttempts = 5;
  static const int maxApiCallsPerMinute = 60;
  
  // Error Messages
  static const String genericErrorMessage = 'Something went wrong. Please try again.';
  static const String networkErrorMessage = 'Please check your internet connection.';
  static const String sessionExpiredMessage = 'Your session has expired. Please login again.';
} 