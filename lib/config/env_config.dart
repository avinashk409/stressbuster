import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseMessagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';
  static String get firebaseStorageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get firebaseDatabaseUrl => dotenv.env['FIREBASE_DATABASE_URL'] ?? '';
  
  static String get appName => dotenv.env['APP_NAME'] ?? 'StressBuster';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';
  static String get agoraAppCertificate => dotenv.env['AGORA_APP_CERTIFICATE'] ?? '';
  
  static String get cashfreeAppId => dotenv.env['CASHFREE_APP_ID'] ?? '';
  static String get cashfreeSecretKey => dotenv.env['CASHFREE_SECRET_KEY'] ?? '';
  static String get cashfreeEnv => dotenv.env['CASHFREE_ENV'] ?? 'TEST';
  
  static bool get isProduction => appEnv == 'production';
} 