import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  // Check if the current user is an admin
  bool get isAdmin => currentUser?.phoneNumber == Config.adminPhoneNumber;

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> verifyPhoneNumber(
      String phoneNumber,
      Function(String) onCodeSent,
      Function(String) onVerified,
      Function(FirebaseAuthException) onError,
      ) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            // Sign in the user
            final userCredential = await _firebaseAuth.signInWithCredential(credential);
            await _firebaseAuth.currentUser?.reload();
            
            // Check if user exists in Firestore
            final userDoc = await _firestore.collection('users').doc(userCredential.user?.uid).get();
            if (!userDoc.exists && userCredential.user != null) {
              // Create new user document for first-time users
              await _firestore.collection('users').doc(userCredential.user!.uid).set({
                'uid': userCredential.user!.uid,
                'phone': userCredential.user!.phoneNumber,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'isNewUser': true,
                'isAdmin': userCredential.user!.phoneNumber == Config.adminPhoneNumber,
              });
            }
            
            onVerified('auto');
          } catch (e) {
            print('Error in verificationCompleted: $e');
            if (e is FirebaseAuthException) {
              onError(e);
            } else {
              onError(FirebaseAuthException(
                code: 'unknown',
                message: 'An unexpected error occurred during auto-verification.'
              ));
            }
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          print('Phone verification failed: ${error.code} - ${error.message}');
          onError(error);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('SMS code sent successfully');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto retrieval timeout');
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print('Error in verifyPhoneNumber: $e');
      if (e is FirebaseAuthException) {
        onError(e);
      } else {
        onError(FirebaseAuthException(
          code: 'unknown',
          message: 'An unexpected error occurred during phone verification.'
        ));
      }
    }
  }

  Future<User?> signInWithOTP(String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      await _firebaseAuth.currentUser?.reload();
      
      // Check if this is a new user
      final user = userCredential.user;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          // Create new user document
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'phone': user.phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isNewUser': true,
            'isAdmin': user.phoneNumber == Config.adminPhoneNumber,
          });
        }
      }
      
      return user;
    } catch (e) {
      print('Error in signInWithOTP: $e');
      rethrow;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      try {
        final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email, 
          password: password
        );
        
        try {
          await _firebaseAuth.currentUser?.reload();
        } catch (reloadError) {
          print('Error reloading user: $reloadError');
          // Continue even if reload fails
        }
        
        return userCredential.user;
      } catch (e) {
        print('Error in signInWithEmailAndPassword: $e');
        
        // Handle the PigeonUserDetails error
        if (e.toString().contains('PigeonUserDetails')) {
          // Just return the current user if we have one
          return _firebaseAuth.currentUser;
        }
        rethrow;
      }
    } catch (e) {
      print('Error in signInWithEmail: $e');
      rethrow;
    }
  }

  Future<User?> registerWithEmail(String email, String password, String name) async {
    try {
      try {
        final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (userCredential.user != null) {
          // Update display name
          await userCredential.user!.updateDisplayName(name);
          
          // Auto create user profile in Firestore
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'email': email,
            'name': name,
            'uid': userCredential.user!.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'emailVerified': false,
          });
          
          await userCredential.user!.sendEmailVerification();
        }
        
        return userCredential.user;
      } catch (e) {
        print('Error in createUserWithEmailAndPassword: $e');
        
        // Handle the PigeonUserDetails error
        if (e.toString().contains('PigeonUserDetails')) {
          // Just return the current user if we have one
          return _firebaseAuth.currentUser;
        }
        rethrow;
      }
    } catch (e) {
      print('Error in registerWithEmail: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile({String? displayName, String? photoURL}) async {
    try {
      if (_firebaseAuth.currentUser != null) {
        if (displayName != null) {
          await _firebaseAuth.currentUser!.updateDisplayName(displayName);
        }
        if (photoURL != null) {
          await _firebaseAuth.currentUser!.updatePhotoURL(photoURL);
        }
        
        try {
          await _firebaseAuth.currentUser!.reload();
        } catch (e) {
          print('Error reloading user during profile update: $e');
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error in updateUserProfile: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      print('Error in deleteAccount: $e');
      rethrow;
    }
  }
}
