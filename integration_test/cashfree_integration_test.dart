import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../lib/screens/cashfree_payment_screen.dart';
import '../lib/services/wallet_service.dart';
import '../test/mocks/mock_services.dart';
import 'package:stressbuster/main.dart' as app;

class CFErrorResponse {
  final String? status;
  final String? message;
  final String? code;
  final String? type;
  CFErrorResponse(this.status, this.message, this.code, this.type);
  @override
  String toString() => message ?? 'Unknown error';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockCashfreeService mockCashfreeService;
  late MockWalletService mockWalletService;
  late MockFirestore mockFirestore;
  late MockAuth mockAuth;

  setUp(() async {
    mockCashfreeService = MockCashfreeService();
    mockFirestore = MockFirestore();
    mockAuth = MockAuth();
    mockWalletService = MockWalletService(auth: mockAuth, firestore: mockFirestore);
    mockAuth.mockUser = MockUser('test-user-id');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CashfreePaymentScreen(
          amount: 100.0,
          purpose: 'Test Payment',
          cashfreeService: mockCashfreeService,
          walletService: mockWalletService,
          firestore: mockFirestore,
          auth: mockAuth,
          disableWebView: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Basic payment flow - success', (WidgetTester tester) async {
    mockCashfreeService.simulateSuccess();
    await pumpApp(tester);
    
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();
    
    expect(find.text('Payment successful!'), findsOneWidget);
  });

  testWidgets('Basic payment flow - error', (WidgetTester tester) async {
    mockCashfreeService.simulateError('Payment failed');
    await pumpApp(tester);
    
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();
    
    expect(find.text('Payment failed'), findsOneWidget);
  });

  testWidgets('Basic payment flow - network error', (WidgetTester tester) async {
    mockCashfreeService.simulateNetworkError();
    await pumpApp(tester);
    
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();
    
    expect(find.text('Network error'), findsOneWidget);
  });

  testWidgets('Complete payment flow with UPI', (WidgetTester tester) async {
    // Setup mock payment service for success
    mockCashfreeService.simulateSuccess();
    mockCashfreeService.setSelectedPaymentMethod('UPI');
    
    await pumpApp(tester);
    
    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    
    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();
    
    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();
    
    // Verify success message
    expect(find.text('Payment successful!'), findsOneWidget);
  });

  testWidgets('Complete payment flow with Card', (WidgetTester tester) async {
    await pumpApp(tester);

    // Select Card payment method
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();

    // Tap proceed to pay
    final proceedButton = find.text('Proceed to Pay');
    expect(proceedButton, findsOneWidget);
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    // Verify processing state
    expect(find.text('Processing payment...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Simulate successful payment
    mockCashfreeService.simulateSuccess();
    await tester.pumpAndSettle();

    // Verify success message in SnackBar
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Payment successful!'), findsOneWidget);
  });

  testWidgets('Handle payment failure with specific error', (WidgetTester tester) async {
    await pumpApp(tester);

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();

    // Tap proceed to pay
    final proceedButton = find.text('Proceed to Pay');
    expect(proceedButton, findsOneWidget);
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    // Verify processing state
    expect(find.text('Processing payment...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Simulate payment failure
    mockCashfreeService.simulateError(
      'Insufficient funds',
      code: 'INSUFFICIENT_FUNDS',
      type: 'BANK_ERROR'
    );
    await tester.pumpAndSettle();

    // Verify error message in SnackBar
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Insufficient funds'), findsOneWidget);
  });

  testWidgets('Handle network connectivity issues', (WidgetTester tester) async {
    await pumpApp(tester);

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();

    // Tap proceed to pay
    final proceedButton = find.text('Proceed to Pay');
    expect(proceedButton, findsOneWidget);
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    // Verify processing state
    expect(find.text('Processing payment...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Simulate network error
    mockCashfreeService.simulateNetworkError();
    await tester.pumpAndSettle();

    // Verify error message in SnackBar
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Network error'), findsOneWidget);
  });

  testWidgets('Handle invalid amount', (WidgetTester tester) async {
    await pumpApp(tester);

    // Enter invalid amount
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.pumpAndSettle();

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();

    // Tap proceed to pay
    final proceedButton = find.text('Proceed to Pay');
    expect(proceedButton, findsOneWidget);
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    // Verify validation message
    expect(find.text('Amount must be greater than 0'), findsOneWidget);
  });

  testWidgets('Handle concurrent payment attempts', (WidgetTester tester) async {
    await pumpApp(tester);

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();

    // Start first payment
    final proceedButton = find.text('Proceed to Pay');
    expect(proceedButton, findsOneWidget);
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    // Try to start another payment immediately
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    // Verify concurrent payment error
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Another payment is in progress'), findsOneWidget);
  });

  testWidgets('Handle payment session expiry', (WidgetTester tester) async {
    await pumpApp(tester);

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();

    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();

    // Simulate session expiry
    mockCashfreeService.simulateSessionExpiry();
    await tester.pumpAndSettle();

    // Verify session expiry SnackBar
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);
    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect((snackBar.content as Text).data, contains('Session expired'));
  });

  testWidgets('Handle payment timeout', (WidgetTester tester) async {
    await pumpApp(tester);

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();

    // Tap proceed to pay
    final proceedButton = find.text('Proceed to Pay');
    expect(proceedButton, findsOneWidget);
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    // Simulate payment timeout
    mockCashfreeService.simulateTimeout();
    await tester.pumpAndSettle();

    // Verify timeout error
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Payment timeout'), findsOneWidget);
  });

  testWidgets('Handle user cancellation', (WidgetTester tester) async {
    await pumpApp(tester);

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();

    // Tap proceed to pay
    final proceedButton = find.text('Proceed to Pay');
    expect(proceedButton, findsOneWidget);
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    // Simulate user cancellation
    mockCashfreeService.simulateCancellation();
    await tester.pumpAndSettle();

    // Verify cancellation error
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Payment cancelled by user'), findsOneWidget);
  });

  testWidgets('Prevent concurrent payments', (WidgetTester tester) async {
    await pumpApp(tester);

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Enter UPI ID
    await tester.enterText(find.byType(TextFormField).last, 'test@upi');
    await tester.pumpAndSettle();

    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();

    // Try to start another payment
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();

    // Verify concurrent payment prevention SnackBar
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);
    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect((snackBar.content as Text).data, contains('Another payment is in progress'));
  });

  testWidgets('successful payment flow', (WidgetTester tester) async {
    // Setup mock payment service for success
    mockCashfreeService.simulateSuccess();
    mockCashfreeService.setSelectedPaymentMethod('UPI');
    
    await pumpApp(tester);
    
    // Verify initial UI state
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    
    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    
    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();
    
    // Verify payment processing state
    expect(find.text('Processing payment...'), findsOneWidget);
    
    // Wait for payment completion
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    
    // Verify success message
    expect(find.text('Payment successful!'), findsOneWidget);
  });

  testWidgets('payment error flow', (WidgetTester tester) async {
    // Setup mock payment service for error
    mockCashfreeService.simulateError(
      'Payment failed due to insufficient funds',
      code: 'INSUFFICIENT_FUNDS',
      type: 'PAYMENT_ERROR'
    );
    
    await pumpApp(tester);
    
    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    
    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();
    
    // Wait for payment completion
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    
    // Verify error message
    expect(find.text('Payment failed due to insufficient funds'), findsOneWidget);
  });

  testWidgets('network error flow', (WidgetTester tester) async {
    // Setup mock payment service for network error
    mockCashfreeService.simulateNetworkError();
    
    await pumpApp(tester);
    
    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    
    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pumpAndSettle();
    
    // Wait for payment completion
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    
    // Verify error message
    expect(find.text('Network error'), findsOneWidget);
  });
}