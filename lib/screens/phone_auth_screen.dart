import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'counselor_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:stressbuster/services/auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  @override
  _PhoneAuthScreenState createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  late final AuthService _auth;
  
  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _acceptedTerms = false;
  String _verificationId = '';
  String? _error;
  int? _resendToken;
  Timer? _timer;
  int _timeoutSeconds = 60;
  
  @override
  void initState() {
    super.initState();
    _auth = Provider.of<AuthService>(context, listen: false);
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  void _startTimer() {
    setState(() {
      _timeoutSeconds = 60;
    });
    
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeoutSeconds > 0) {
          _timeoutSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }
  
  Future<void> _verifyPhone() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.verifyPhoneNumber(
        _phoneController.text,
        (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isOtpSent = true;
            _isLoading = false;
          });
          _startTimer();
        },
        (String message) async {
          await _handleSuccessfulAuth();
        },
        (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
          setState(() {
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _auth.signInWithOTP(_verificationId, _otpController.text);
      if (user != null) {
        await _handleSuccessfulAuth();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid OTP. Please try again.')),
      );
    }
  }
  
  Future<void> _handleSuccessfulAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Check if this is a new user
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) {
      // Create new user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'phone': user.phoneNumber,
        'name': _nameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isNewUser': true,
      });
    } else {
      // Update existing user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'phone': user.phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    // Check user role and redirect
    await _checkUserRoleAndRedirect();
  }
  
  Future<void> _checkUserRoleAndRedirect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final idTokenResult = await user.getIdTokenResult(true);
      final role = idTokenResult.claims?['role'];
      
      if (role == 'counselor') {
        Navigator.pushReplacementNamed(context, '/counselor-dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/user-dashboard');
      }
    } catch (e) {
      // Default to user dashboard if role check fails
      Navigator.pushReplacementNamed(context, '/user-dashboard');
    }
  }
  
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'The phone number format is invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Please contact support.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid. Please try again.';
      case 'session-expired':
        return 'The verification session has expired. Please request a new code.';
      default:
        return 'An error occurred: $code';
    }
  }
  
  Future<void> _resendOTP() async {
    if (_timeoutSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait ${_timeoutSeconds} seconds before resending')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${_phoneController.text.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (Android only)
          setState(() {
            _isLoading = false;
          });
          
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await _handleSuccessfulAuth();
          } catch (e) {
            setState(() {
              _error = 'Auto-verification failed: $e';
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _error = _getErrorMessage(e.code);
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          
          _startTimer();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP resent successfully')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phone Authentication'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login_background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Phone Authentication',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enter your phone number to continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  
                  if (_error != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  
                  SizedBox(height: 24),
                  
                  if (!_isOtpSent) ...[
                    // Phone number input
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter 10-digit phone number',
                        prefixText: '+91 ',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.length != 10) {
                          return 'Please enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Name input (only for new users)
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Terms and conditions
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the Terms and Conditions',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Send OTP button
                    ElevatedButton(
                      onPressed: _acceptedTerms ? _verifyPhone : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Send OTP',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ] else ...[
                    // OTP input
                    Text(
                      'Enter the 6-digit code sent to +91${_phoneController.text}',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _otpController,
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        hintText: 'Enter 6-digit OTP',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the OTP';
                        }
                        if (value.length != 6) {
                          return 'Please enter a valid 6-digit OTP';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Resend OTP button
                    TextButton(
                      onPressed: _timeoutSeconds > 0 ? null : _resendOTP,
                      child: Text(
                        _timeoutSeconds > 0
                            ? 'Resend OTP in $_timeoutSeconds seconds'
                            : 'Resend OTP',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Verify OTP button
                    ElevatedButton(
                      onPressed: _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Verify OTP',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Change phone number button
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isOtpSent = false;
                          _otpController.clear();
                          _timer?.cancel();
                        });
                      },
                      child: Text(
                        'Change Phone Number',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 