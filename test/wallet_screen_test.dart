import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stressbuster/screens/wallet_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Firebase for testing with emulator configuration
    await Firebase.initializeApp();
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8082);
  });

  group('Wallet Screen Tests', () {
    testWidgets('Wallet screen displays correctly', (WidgetTester tester) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(MaterialApp(
        home: WalletScreen(),
      ));

      // Verify that the wallet screen is displayed
      expect(find.byType(WalletScreen), findsOneWidget);
    });

    testWidgets('Wallet balance is displayed', (WidgetTester tester) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(MaterialApp(
        home: WalletScreen(),
      ));

      // Verify that the balance text is displayed
      expect(find.text('Balance'), findsOneWidget);
    });
  });
} 