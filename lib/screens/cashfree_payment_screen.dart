import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/wallet_service.dart';
import '../services/cashfree_service.dart';

class CashfreePaymentScreen extends StatefulWidget {
  final double amount;
  final String purpose;
  final String? counselorId;
  final CashfreeService? cashfreeService;
  final WalletService? walletService;
  final WebViewController? webViewController;
  final bool disableWebView;
  final dynamic firestore;
  final dynamic auth;

  const CashfreePaymentScreen({
    Key? key,
    required this.amount,
    required this.purpose,
    this.counselorId,
    this.cashfreeService,
    this.walletService,
    this.webViewController,
    this.disableWebView = false,
    this.firestore,
    this.auth,
  }) : super(key: key);

  @override
  State<CashfreePaymentScreen> createState() => _CashfreePaymentScreenState();
}

class _CashfreePaymentScreenState extends State<CashfreePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  late final WalletService _walletService;
  late final CashfreeService _cashfreeService;
  late final dynamic _firestore;
  late final dynamic _auth;
  bool _isProcessing = false;
  bool _showWebView = false;
  String? _paymentSessionId;
  late WebViewController _webViewController;
  String? _selectedPaymentMethod;
  double _amount = 0;
  String _orderId = '';
  Timer? _sessionTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _walletService = widget.walletService ?? WalletService();
    _cashfreeService = widget.cashfreeService ?? CashfreeService();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;
    _amountController.text = widget.amount.toString();
    _amount = widget.amount;
    if (!widget.disableWebView) {
      _initWebView();
    }
    _setupPaymentCallbacks();
    _startSessionTimeoutCheck();
  }

  void _setupPaymentCallbacks() {
    _cashfreeService.setPaymentCallbacks(
      onSuccess: _onPaymentComplete,
      onError: _onPaymentError,
    );
  }

  void _onPaymentComplete(String orderId) async {
    if (!mounted) return;
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      if (orderId.isEmpty) throw Exception('Order ID is empty');

      // Update transaction status
      await _firestore.collection('transactions').doc(orderId).update({
        'status': 'SUCCESS',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Add funds to user's wallet
      await _walletService.addFunds(user.uid, _amount);

      if (!mounted) return;

      // If this is a counselor payment, update their earnings
      if (widget.counselorId != null) {
        await _walletService.updateCounselorEarnings(widget.counselorId!, _amount);
      }

      if (!mounted) return;

      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      print('Error processing payment completion: $e');
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error processing payment. Please contact support.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPaymentError(dynamic errorResponse, String orderId) async {
    if (!mounted) return;
    
    try {
      if (orderId.isEmpty) throw Exception('Order ID is empty');

      // Update transaction status
      await _firestore.collection('transactions').doc(orderId).update({
        'status': 'FAILED',
        'error': errorResponse.toString(),
        'errorCode': errorResponse.code,
        'errorType': errorResponse.type,
        'updatedAt': FieldValue.serverTimestamp(),
        'retryCount': FieldValue.increment(1),
      });

      if (!mounted) return;

      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorResponse.message ?? 'Payment failed'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      print('Error processing payment failure: $e');
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error processing payment. Please contact support.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _initWebView() {
    _webViewController = widget.webViewController ?? WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('stressbuster://payment/callback')) {
              final uri = Uri.parse(request.url);
              final orderId = uri.queryParameters['order_id'];
              final status = uri.queryParameters['payment_status'];
              if (orderId != null && status != null) {
                _handlePaymentStatus(orderId, status);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _initiateCashfreePayment() async {
    if (!mounted) return;
    
    if (!_formKey.currentState!.validate() || _selectedPaymentMethod == null) {
      if (!mounted) return;
      _showError('Please select a payment method');
      return;
    }

    setState(() => _isProcessing = true);
    // Artificial delay for test visibility
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get user's phone number from Firestore
      final userData = await _firestore.collection('users').doc(user.uid).get();
      if (!userData.exists) {
        throw Exception('User data not found');
      }
      
      final phoneNumber = userData.data()?['phone'] as String?;
      if (phoneNumber == null || phoneNumber.isEmpty) {
        throw Exception('User phone number not found');
      }

      // Create order
      _orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
      await _cashfreeService.createOrder(
        orderId: _orderId,
        amount: _amount,
        customerId: user.uid,
        customerEmail: user.email ?? '',
        customerPhone: phoneNumber,
        customerName: user.displayName ?? userData.data()?['name'] ?? 'User',
      );

      if (!mounted) return;

      // Create payment session
      _paymentSessionId = await _cashfreeService.createPaymentSession(
        orderId: _orderId,
        paymentMethod: _selectedPaymentMethod,
      );

      if (!mounted) return;

      // Create transaction record
      await _firestore.collection('transactions').doc(_orderId).set({
        'userId': user.uid,
        'amount': _amount,
        'status': 'PENDING',
        'timestamp': FieldValue.serverTimestamp(),
        'purpose': widget.purpose,
        'paymentMethod': _selectedPaymentMethod,
        'retryCount': 0,
      });

      if (!mounted) return;

      // Start payment
      await _cashfreeService.doPayment(_orderId, _paymentSessionId!);

      if (!mounted) return;

      // Start session timeout check
      _startSessionTimeoutCheck();
    } catch (e) {
      if (!mounted) return;
      print('Error initiating payment: $e');
      _showError(e.toString());
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePaymentStatus(String orderId, String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      if (orderId.isEmpty) throw Exception('Order ID is empty');

      // Update transaction in Firestore
      await _firestore.collection('transactions').doc(orderId).set({
        'userId': user.uid,
        'amount': _amount,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'purpose': widget.purpose,
        'counselorId': widget.counselorId,
        'paymentMethod': _selectedPaymentMethod,
      });

      // If payment is successful, update user's wallet
      if (status == 'SUCCESS') {
        await _walletService.addFunds(user.uid, _amount);
        
        // If this is a counselor payment, update the counselor's earnings
        if (widget.counselorId != null) {
          await _walletService.updateCounselorEarnings(widget.counselorId!, _amount);
        }

        _showSuccess('Payment successful!');
      } else {
        _showError('Payment failed. Please try again.');
      }

      // Navigate back
      if (mounted) {
        Navigator.of(context).pop(status == 'SUCCESS');
      }
    } catch (e) {
      print('Error handling payment status: $e');
      _showError('Error processing payment. Please contact support.');
    }
  }

  void _startSessionTimeoutCheck() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = Timer(const Duration(minutes: 15), () {
      if (mounted && _isProcessing) {
        _showError('Payment session timed out. Please try again.');
        setState(() => _isProcessing = false);
      }
    });
  }

  @override
  void dispose() {
    _sessionTimeoutTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹',
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Select Payment Method',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentMethodTile(
                      'UPI',
                      Icons.account_balance,
                      'Pay using any UPI app',
                    ),
                    _buildPaymentMethodTile(
                      'Card',
                      Icons.credit_card,
                      'Credit/Debit Card',
                    ),
                    _buildPaymentMethodTile(
                      'Netbanking',
                      Icons.account_balance_wallet,
                      'Internet Banking',
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _selectedPaymentMethod == null
                          ? null
                          : _initiateCashfreePayment,
                      child: const Text('Proceed to Pay'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPaymentMethodTile(String method, IconData icon, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(method),
        subtitle: Text(subtitle),
        selected: _selectedPaymentMethod == method,
        onTap: () => setState(() => _selectedPaymentMethod = method),
        trailing: _selectedPaymentMethod == method
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

