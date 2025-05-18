import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stressbuster/screens/login_screen.dart';
import 'package:stressbuster/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen_test.mocks.dart';

class DummyScreen extends StatelessWidget {
  final String label;
  const DummyScreen(this.label, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}

@GenerateMocks([
  AuthService,
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  User,
])
void main() {
  late MockAuthService mockAuthService;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDoc;
  late MockUser mockUser;

  setUp(() {
    mockAuthService = MockAuthService();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockDoc = MockDocumentSnapshot();
    mockUser = MockUser();

    // Setup default mock behavior
    when(mockFirestore.collection('users')).thenReturn(mockCollection);
    when(mockCollection.doc(any)).thenReturn(mockDocRef);
    when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
    when(mockDoc.exists).thenReturn(true);
    when(mockDoc.data()).thenReturn({});
    when(mockUser.uid).thenReturn('test-uid');
    when(mockUser.phoneNumber).thenReturn('+919876543210');
  });

  Widget createLoginScreen() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: mockAuthService,
        child: LoginScreen(firestore: mockFirestore),
      ),
      routes: {
        '/user-dashboard': (_) => const DummyScreen('User Dashboard'),
        '/counselor-dashboard': (_) => const DummyScreen('Counselor Dashboard'),
        '/admin': (_) => const DummyScreen('Admin Panel'),
      },
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('Phone number field is visible', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Phone Number'), findsOneWidget);
    });

    testWidgets('OTP button works', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();
      when(mockAuthService.verifyPhoneNumber(
        any,
        any,
        any,
        any,
      )).thenAnswer((invocation) {
        final Function(String) codeSent = invocation.positionalArguments[1];
        codeSent('dummy_verification_id');
        return Future.value();
      });
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '9876543210');
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Enter OTP'), findsOneWidget);
    });

    testWidgets('Navigation to dashboard after OTP verification', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      // Mock phone verification
      when(mockAuthService.verifyPhoneNumber(
        any,
        any,
        any,
        any,
      )).thenAnswer((invocation) {
        final Function(String) codeSent = invocation.positionalArguments[1];
        codeSent('dummy_verification_id');
        return Future.value();
      });

      // Mock OTP verification
      when(mockAuthService.signInWithOTP(any, any)).thenAnswer((_) => Future.value(mockUser));

      // Enter phone number and accept terms
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '9876543210');
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      // Send OTP
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pump();

      // Enter OTP
      await tester.enterText(find.widgetWithText(TextFormField, 'Enter OTP'), '123456');
      await tester.pump();

      // Verify OTP
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify OTP'));
      await tester.pumpAndSettle();

      // Verify navigation to user dashboard
      expect(find.text('User Dashboard'), findsOneWidget);
    });
  });
} 