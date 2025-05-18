import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stressbuster/screens/wallet_screen.dart';
import 'package:stressbuster/screens/cashfree_payment_screen.dart';
import 'package:stressbuster/services/wallet_service.dart';
import 'package:stressbuster/services/cashfree_service.dart';

@GenerateMocks([
  WalletService,
  CashfreeService,
  FirebaseAuth,
  User,
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  Query,
])
void main() {
  late MockWalletService mockWalletService;
  late MockCashfreeService mockCashfreeService;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockTransactionsCollection;
  late MockDocumentReference mockTransactionDoc;

  setUp(() {
    mockWalletService = MockWalletService();
    mockCashfreeService = MockCashfreeService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockFirestore = MockFirebaseFirestore();
    mockTransactionsCollection = MockCollectionReference();
    mockTransactionDoc = MockDocumentReference();

    // Setup mock user
    when(mockUser.uid).thenReturn('test_user_id');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');
    when(mockAuth.currentUser).thenReturn(mockUser);

    // Setup mock Firestore
    when(mockFirestore.collection('transactions')).thenReturn(mockTransactionsCollection);
    when(mockTransactionsCollection.doc(any)).thenReturn(mockTransactionDoc);
    when(mockTransactionDoc.set(any)).thenAnswer((_) async => null);
    when(mockTransactionDoc.update(any)).thenAnswer((_) async => null);

    // Setup mock wallet service
    when(mockWalletService.getBalance()).thenAnswer((_) async => 100.0);
    when(mockWalletService.addFunds(any, any)).thenAnswer((_) async => null);
  });

  testWidgets('successful payment flow', (WidgetTester tester) async {
    // Build the wallet screen
    await tester.pumpWidget(
      MaterialApp(
        home: WalletScreen(),
      ),
    );

    // Wait for initial balance load
    await tester.pumpAndSettle();

    // Verify initial balance is displayed
    expect(find.text('₹100.00'), findsOneWidget);

    // Tap the "Add Money" button
    await tester.tap(find.text('Add Money'));
    await tester.pumpAndSettle();

    // Verify CashfreePaymentScreen is shown
    expect(find.byType(CashfreePaymentScreen), findsOneWidget);

    // Enter amount
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.pumpAndSettle();

    // Select payment method (UPI)
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Tap proceed button
    await tester.tap(find.text('Proceed'));
    await tester.pumpAndSettle();

    // Simulate successful payment
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    when(mockCashfreeService.createOrder(
      orderId: anyNamed('orderId'),
      amount: anyNamed('amount'),
      customerId: anyNamed('customerId'),
      customerEmail: anyNamed('customerEmail'),
      customerPhone: anyNamed('customerPhone'),
      customerName: anyNamed('customerName'),
    )).thenAnswer((_) async => null);

    when(mockCashfreeService.createPaymentSession(
      orderId: anyNamed('orderId'),
      paymentMethod: anyNamed('paymentMethod'),
    )).thenAnswer((_) async => 'test_session_id');

    // Simulate payment completion
    await mockCashfreeService.onPaymentComplete?.call(orderId);
    await tester.pumpAndSettle();

    // Verify success message
    expect(find.text('Payment successful!'), findsOneWidget);

    // Verify balance is updated
    verify(mockWalletService.addFunds('test_user_id', 500.0)).called(1);
    verify(mockTransactionDoc.update({
      'status': 'SUCCESS',
      'updatedAt': any,
    })).called(1);

    // Verify navigation back to wallet screen
    expect(find.byType(WalletScreen), findsOneWidget);
  });

  testWidgets('payment error handling', (WidgetTester tester) async {
    // Build the wallet screen
    await tester.pumpWidget(
      MaterialApp(
        home: WalletScreen(),
      ),
    );

    // Wait for initial balance load
    await tester.pumpAndSettle();

    // Tap the "Add Money" button
    await tester.tap(find.text('Add Money'));
    await tester.pumpAndSettle();

    // Enter amount
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.pumpAndSettle();

    // Select payment method (UPI)
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    // Tap proceed button
    await tester.tap(find.text('Proceed'));
    await tester.pumpAndSettle();

    // Simulate payment error
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    when(mockCashfreeService.createOrder(
      orderId: anyNamed('orderId'),
      amount: anyNamed('amount'),
      customerId: anyNamed('customerId'),
      customerEmail: anyNamed('customerEmail'),
      customerPhone: anyNamed('customerPhone'),
      customerName: anyNamed('customerName'),
    )).thenThrow(Exception('Payment failed'));

    // Verify error message
    expect(find.text('Payment failed'), findsOneWidget);

    // Verify transaction is marked as failed
    verify(mockTransactionDoc.update({
      'status': 'FAILED',
      'error': any,
      'updatedAt': any,
      'retryCount': any,
    })).called(1);
  });
} 