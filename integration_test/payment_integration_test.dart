import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stressbuster/screens/cashfree_payment_screen.dart';
import 'package:stressbuster/services/cashfree_service.dart';
import 'package:stressbuster/services/wallet_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late CashfreeService cashfreeService;
  late WalletService walletService;
  late FirebaseFirestore firestore;
  late FirebaseAuth auth;

  setUpAll(() async {
    await Firebase.initializeApp();
    cashfreeService = CashfreeService();
    walletService = WalletService();
    firestore = FirebaseFirestore.instance;
    auth = FirebaseAuth.instance;
  });

  group('Payment Integration Tests', () {
    testWidgets('Payment Screen Initialization Test', (WidgetTester tester) async {
      // Launch payment screen
      await tester.pumpWidget(MaterialApp(
        home: CashfreePaymentScreen(
          amount: 100.0,
          purpose: 'Wallet Recharge',
          cashfreeService: cashfreeService,
          walletService: walletService,
          firestore: firestore,
          auth: auth,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify initial UI
      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget); // Amount field
      expect(find.byType(ElevatedButton), findsOneWidget); // Pay button
    });

    testWidgets('Payment Error Handling Test', (WidgetTester tester) async {
      // Launch payment screen with invalid amount
      await tester.pumpWidget(MaterialApp(
        home: CashfreePaymentScreen(
          amount: 0.0, // Invalid amount
          purpose: 'Wallet Recharge',
          cashfreeService: cashfreeService,
          walletService: walletService,
          firestore: firestore,
          auth: auth,
        ),
      ));
      await tester.pumpAndSettle();

      // Try to proceed with payment
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify SnackBar is shown
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Payment Processing Test', (WidgetTester tester) async {
      // Launch payment screen
      await tester.pumpWidget(MaterialApp(
        home: CashfreePaymentScreen(
          amount: 100.0,
          purpose: 'Wallet Recharge',
          cashfreeService: cashfreeService,
          walletService: walletService,
          firestore: firestore,
          auth: auth,
        ),
      ));
      await tester.pumpAndSettle();

      // Enter amount
      await tester.enterText(find.byType(TextFormField), '100.0');
      await tester.pumpAndSettle();

      // Tap pay button
      await tester.tap(find.byType(ElevatedButton));
      // Wait up to 3 seconds for the CircularProgressIndicator to appear
      bool found = false;
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'Should show loading indicator after tapping pay');
    });
  });
} 