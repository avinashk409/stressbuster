import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/phone_auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/counselor_dashboard.dart';
import 'screens/admin_panel.dart';
import 'screens/call_screen.dart';
import 'firebase_options.dart';
import 'config/prod_config.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Ensure we're using the existing Firebase instance
    if (Firebase.apps.isEmpty) {
      print('Warning: No Firebase apps found in background handler');
      return;
    }
    print("Handling a background message: ${message.messageId}");
  } catch (e) {
    print("Error in background handler: $e");
  }
}

// Add this function to ensure an admin user exists
Future<void> _createAdminUserIfNeeded() async {
  try {
    // Read from a special file that contains admin emails
    const adminEmails = ['admin@stressbuster.com']; // Add your admin emails here
    
    // Check if any admin user already exists
    final adminQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('isAdmin', isEqualTo: true)
        .limit(1)
        .get();
    
    if (adminQuery.docs.isNotEmpty) {
      print('Admin user already exists');
      return;
    }
    
    // Check the current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Check if the current user's email is in the admin list
      if (adminEmails.contains(currentUser.email)) {
        try {
          // Create a new user document with admin privileges
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set({
                'email': currentUser.email,
                'name': currentUser.displayName ?? 'Admin User',
                'isAdmin': true,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          print('Created/Updated admin user in Firestore');
        } catch (e) {
          print('Error creating/updating admin user: $e');
        }
      }
    }
  } catch (e) {
    print('Error in _createAdminUserIfNeeded: $e');
  }
}

// Helper function to check if an asset exists
Future<bool> assetExists(String assetPath) async {
  try {
    await rootBundle.load(assetPath);
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    // Request SMS permission
    await Permission.sms.request();
    
    // Request phone state permission
    await Permission.phone.request();
  }
}

// Initialize Firebase with proper error handling
Future<void> initializeFirebase() async {
  try {
    print('Checking Firebase initialization status...');
    
    // Try to get the default app first
    try {
      final app = Firebase.app();
      print('Firebase already initialized at native level');
      return;
    } catch (e) {
      print('No existing Firebase app found, initializing new one...');
    }
    
    // If no app exists, initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');

    // Initialize App Check based on environment
    if (kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      print('Firebase App Check initialized with debug provider');
    } else {
      await ProdConfig.initialize();
      print('Firebase App Check initialized with production provider');
    }
  } catch (e) {
    print('Error during Firebase initialization: $e');
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing...');
      return;
    }
    rethrow;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST, before anything else
  await initializeFirebase();

  try {
    // Set persistence for better offline support
    try {
      await FirebaseFirestore.instance.enablePersistence(const PersistenceSettings(synchronizeTabs: true));
      print('Firestore persistence enabled');
    } catch (e) {
      print('Warning: Could not enable Firestore persistence: $e');
      // Continue without persistence
    }
    
    print('Firebase setup completed successfully');
  } catch (e) {
    print('Error during Firebase setup: $e');
    // Show a more user-friendly error
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to initialize app. Please try again later.'),
              SizedBox(height: 16),
              Text('Error: $e', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    ));
    return;
  }

  try {
    // Request permissions
    await _requestPermissions();

    // Load environment variables
    try {
      print('Loading environment variables...');
      await dotenv.load(fileName: ".env");
      print('Environment variables loaded successfully');
    } catch (e) {
      print('Warning: Could not load .env file. Using default Firebase configuration.');
    }

    // Initialize Firebase services
    if (kDebugMode) {
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      print('Debug mode enabled - Crashlytics disabled');
    }

    // Register background handler for Firebase Messaging
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('Firebase Messaging background handler registered');

    // Initialize notifications
    await _initNotifications();

    // Create admin user if needed
    await _createAdminUserIfNeeded();

    // Add error handling for the app
    FlutterError.onError = (FlutterErrorDetails details) {
      print('Flutter error: ${details.exception}');
      print('Stack trace: ${details.stack}');
    };

    runApp(MyApp());
  } catch (e) {
    print('Error during app initialization: $e');
    runApp(ErrorScreen(errorMessage: e.toString()));
  }
}

Future<void> _initNotifications() async {
  try {
    // Ensure Firebase is initialized
    if (Firebase.apps.isEmpty) {
      print('Warning: No Firebase apps found in notifications initialization');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    
    // Request permission
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Get FCM token
      try {
        final token = await messaging.getToken();
        print('FCM Token: $token');
        
        // Save token to Firestore when user is logged in
        if (token != null) {
          FirebaseAuth.instance.authStateChanges().listen((User? user) {
            if (user != null) {
              try {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({'fcmToken': token}, SetOptions(merge: true));
              } catch (e) {
                print('Error saving FCM token to Firestore: $e');
              }
            }
          });
        }
      } catch (e) {
        print('Error getting FCM token: $e');
      }
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
        
        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification!.title}');
        }
      }, onError: (error) {
        print('Error on foreground message: $error');
      });
    } else {
      print('User declined or has not accepted permission');
    }
  } catch (e) {
    print('Error in _initNotifications: $e');
  }
}

// Safe wrapper for Firebase auth state changes to handle errors
Stream<User?> safeAuthStateChanges() {
  StreamController<User?> controller = StreamController<User?>();
  
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    controller.add(user);
  }, onError: (error) {
    print('AuthStateChanges stream error: $error');
    // Don't propagate the error, just log it
    if (error.toString().contains('PigeonUserDetails')) {
      print('Handling PigeonUserDetails error in auth state');
      // Try to get the current user directly
      final currentUser = FirebaseAuth.instance.currentUser;
      controller.add(currentUser);
    } else {
      // For other errors, we'll pass null user
      controller.add(null);
    }
  });
  
  return controller.stream;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'StressBuster',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: LoginScreen(),
        routes: {
          '/login': (context) => LoginScreen(),
          '/user-dashboard': (context) => DashboardScreen(),
          '/counselor-dashboard': (context) => CounselorDashboard(),
          '/admin': (context) => AdminPanel(),
        },
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String? errorMessage;
  const ErrorScreen({this.errorMessage, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Failed to initialize app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Please try again later',
                style: TextStyle(fontSize: 16),
              ),
              if (errorMessage != null) ...[
                SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(fontSize: 14, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
