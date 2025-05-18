import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import '../../lib/screens/cashfree_payment_screen.dart';
import '../mocks/mock_services.dart';
import '../mocks/mock_webview.dart';

void main() {
  late MockCashfreeService mockCashfreeService;
  late MockWalletService mockWalletService;
  late MockFirebaseUser mockUser;
  late MockWebViewController mockWebViewController;

  setUp(() {
    mockCashfreeService = MockCashfreeService();
    mockWalletService = MockWalletService();
    mockUser = MockFirebaseUser();
    mockWebViewController = MockWebViewController();
  });

  testWidgets('Initial UI state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CashfreePaymentScreen(
          amount: 100.0,
          purpose: 'test_payment',
          cashfreeService: mockCashfreeService,
          walletService: mockWalletService,
          webViewController: mockWebViewController,
          disableWebView: true,
        ),
      ),
    );

    // Verify initial UI elements
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Select Payment Method'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Netbanking'), findsOneWidget);
    expect(find.text('Proceed to Pay'), findsOneWidget);
  });

  testWidgets('Select payment method', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CashfreePaymentScreen(
          amount: 100.0,
          purpose: 'test_payment',
          cashfreeService: mockCashfreeService,
          walletService: mockWalletService,
          webViewController: mockWebViewController,
          disableWebView: true,
        ),
      ),
    );

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Verify UPI is selected
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('Shows loading state when processing payment', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CashfreePaymentScreen(
          amount: 100.0,
          purpose: 'test_payment',
          cashfreeService: mockCashfreeService,
          walletService: mockWalletService,
          webViewController: mockWebViewController,
          disableWebView: true,
        ),
      ),
    );

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify processing state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Processing payment...'), findsOneWidget);
  });

  testWidgets('Shows success message after payment', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CashfreePaymentScreen(
          amount: 100.0,
          purpose: 'test_payment',
          cashfreeService: mockCashfreeService,
          walletService: mockWalletService,
          webViewController: mockWebViewController,
          disableWebView: true,
        ),
      ),
    );

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Simulate successful payment
    mockCashfreeService.simulateSuccess('test_order_id');
    await tester.pumpAndSettle();

    // Verify success message
    expect(find.text('Payment successful!'), findsOneWidget);
  });

  testWidgets('Shows failure message after payment', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CashfreePaymentScreen(
          amount: 100.0,
          purpose: 'test_payment',
          cashfreeService: mockCashfreeService,
          walletService: mockWalletService,
          webViewController: mockWebViewController,
          disableWebView: true,
        ),
      ),
    );

    // Select UPI payment method
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Tap proceed to pay
    await tester.tap(find.text('Proceed to Pay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Simulate payment failure
    final error = CFErrorResponse(
      'FAILED',
      'Payment declined by bank',
      'PAYMENT_DECLINED',
      'BANK_ERROR',
    );
    mockCashfreeService.simulateError(error, 'test_order_id');
    await tester.pumpAndSettle();

    // Verify error message
    expect(find.text('Payment failed. Please try again.'), findsOneWidget);
  });
} 