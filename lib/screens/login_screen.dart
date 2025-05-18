import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stressbuster/widgets/image_widget.dart';
import 'dart:io';
import 'dart:math' as math;
import 'phone_auth_screen.dart';
import 'package:provider/provider.dart';
import 'package:stressbuster/services/auth_service.dart';

import 'dashboard_screen.dart'; // for regular users
import 'counselor_dashboard.dart'; // for counselors
import 'admin_panel.dart'; // for admin users

class LoginScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  LoginScreen({Key? key, FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance,
        super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _acceptedTerms = false;

  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _error;

  late final AuthService _auth;
  
  @override
  void initState() {
    super.initState();
    _auth = Provider.of<AuthService>(context, listen: false);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// 🔑 This function checks the user's role and redirects accordingly.
  Future<void> checkUserRoleAndRedirect(User? user) async {
    if (user == null) {
      setState(() {
        _error = 'Authentication failed. User is null.';
        _isLoading = false;
      });
      return;
    }
    
    try {
      // Get user data from Firestore
      final userDoc = await widget.firestore
          .collection('users')
          .doc(user.uid)
          .get();
      
      setState(() => _isLoading = false);
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          // Check user roles
          if (userData['isAdmin'] == true) {
            Navigator.of(context).pushReplacementNamed('/admin');
          } else if (userData['isCounselor'] == true) {
            Navigator.of(context).pushReplacementNamed('/counselor-dashboard');
          } else {
            Navigator.of(context).pushReplacementNamed('/user-dashboard');
          }
          return;
        }
      }
      
      // If no user document or role, create one with default user role
      await widget.firestore.collection('users').doc(user.uid).set({
        'phone': user.phoneNumber ?? '',
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedTerms': true,
      }, SetOptions(merge: true));
      
      // Redirect to user dashboard
      Navigator.of(context).pushReplacementNamed('/user-dashboard');
    } catch (e) {
      print('Error in checkUserRoleAndRedirect: $e');
      
      // Default to user dashboard on error
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacementNamed('/user-dashboard');
    }
  }

  Future<void> _verifyPhone() async {
    if (!_acceptedTerms) {
      setState(() {
        _error = 'Please accept the terms and conditions';
      });
      return;
    }

    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() {
        _error = 'Please enter your phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _auth.verifyPhoneNumber(
        '+91$phoneNumber',
        (String verificationId) {
          // OTP sent successfully
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
            _error = null;
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP sent successfully')),
          );
        },
        (String message) async {
          // Auto-verification completed
          setState(() {
            _isLoading = false;
            _error = null;
          });
          await checkUserRoleAndRedirect(_auth.currentUser);
        },
        (FirebaseAuthException e) {
          print('Phone verification error: ${e.code} - ${e.message}');
          setState(() {
            _isLoading = false;
            _error = _getErrorMessage(e.code);
          });
        },
      );
    } catch (e) {
      print('Unexpected error in _verifyPhone: $e');
      setState(() {
        _isLoading = false;
        _error = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter the OTP')),
      );
      return;
    }

    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please request OTP first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _auth.signInWithOTP(_verificationId!, otp);
      if (!mounted) return;
      
      await checkUserRoleAndRedirect(user);
    } catch (e) {
      print('OTP verification error: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _error = e is FirebaseAuthException 
          ? _getErrorMessage(e.code)
          : 'Failed to verify OTP. Please try again.';
      });
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again';
      case 'invalid-verification-id':
        return 'Session expired. Please request OTP again';
      case 'session-expired':
        return 'OTP session expired. Please request a new code';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'An error occurred. Please try again';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationX(math.pi), // Flips the image vertically
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/login_background.jpg'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.4),
                      BlendMode.darken,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 40),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology_alt,
                          size: 80,
                          color: Color(0xFFE34F26),
                        ),
                      ),
                      SizedBox(height: 40),
                      Text(
                        'Welcome to StressBuster',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      if (!_otpSent) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixText: '+91 ',
                            prefixStyle: TextStyle(color: Colors.white),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        CheckboxListTile(
                          value: _acceptedTerms,
                          onChanged: (value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                            });
                          },
                          title: Text(
                            'I accept the Terms and Conditions',
                            style: TextStyle(color: Colors.white),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyPhone,
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Send OTP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color(0xFFE34F26),
                            padding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Enter OTP',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOTP,
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Verify OTP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color(0xFFE34F26),
                            padding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        SizedBox(height: 20),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
