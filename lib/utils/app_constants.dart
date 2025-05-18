import 'package:flutter/material.dart';

class AppConstants {
  // Agora Video Calling Configuration
  // This is a placeholder App ID - replace with an actual App ID in production
  static const String agoraAppId = '2a1ebb97c29949f0ae4b12d36b15c2fc'; 
  
  // Default channel name format for video calls (roomCode is used as base)
  static String getChannelName(String roomCode) {
    return 'stressbuster_$roomCode';
  }
  
  // App Theme Colors
  static const Color primaryColor = Color(0xFF6200EE);
  static const Color accentColor = Color(0xFF03DAC5);
  static const Color errorColor = Color(0xFFB00020);
  
  // Button Styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: primaryColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
  
  // App Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );
  
  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );
  
  // API Timeout Duration
  static const Duration apiTimeout = Duration(seconds: 15);
} 