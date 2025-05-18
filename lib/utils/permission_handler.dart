import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// Request camera and microphone permissions needed for video calling
  static Future<bool> requestCameraAndMicPermission(BuildContext context) async {
    // Request camera permission
    var cameraStatus = await Permission.camera.request();
    
    // Request microphone permission
    var microphoneStatus = await Permission.microphone.request();
    
    if (cameraStatus.isGranted && microphoneStatus.isGranted) {
      return true;
    } else {
      // Show alert dialog if permissions are denied
      if (context.mounted) {
        showPermissionDeniedDialog(context);
      }
      return false;
    }
  }
  
  /// Check if camera and microphone permissions are granted
  static Future<bool> checkCameraAndMicPermission() async {
    return await Permission.camera.isGranted && 
           await Permission.microphone.isGranted;
  }

  /// Show a dialog explaining why permissions are needed
  static void showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Camera and microphone permissions are required for video calls. '
          'Please enable them in your device settings to continue.'
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
} 