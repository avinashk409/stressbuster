import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:stressbuster/screens/profile_screen.dart';
import 'profile_screen_test.mocks.dart';

class DummyScreen extends StatelessWidget {
  final String label;
  const DummyScreen(this.label, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}

@GenerateMocks([
  FirebaseAuth,
  User,
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDoc;

  const testUserData = {
    'name': 'John Doe',
    'age': '25',
    'gender': 'Male',
    'email': 'john@example.com',
    'walletBalance': 1000.0,
  };

  setupFirebaseAuthMocks() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockDoc = MockDocumentSnapshot();

    // Setup default mock behavior
    when(mockUser.uid).thenReturn('test-uid');
    when(mockUser.email).thenReturn('john@example.com');
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockFirestore.collection('users')).thenReturn(mockCollection);
    when(mockCollection.doc(any)).thenReturn(mockDocRef);
    when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
    when(mockDoc.exists).thenReturn(true);
    when(mockDoc.data()).thenReturn(testUserData);
  }

  Widget createProfileScreen() {
    return MaterialApp(
      home: ProfileScreen(firestore: mockFirestore, auth: mockAuth),
    );
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setupFirebaseAuthMocks();
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('displays user profile information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createProfileScreen());
      await tester.pump();

      // Verify wallet balance is displayed
      expect(find.text('Wallet Balance'), findsOneWidget);
      expect(find.text('₹1000.00'), findsOneWidget);

      // Verify email is displayed
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('john@example.com'), findsOneWidget);

      // Verify name field is populated
      expect(find.widgetWithText(TextFormField, 'Full Name'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);

      // Verify age field is populated
      expect(find.widgetWithText(TextFormField, 'Age'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      // Verify gender dropdown is populated
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'Gender'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
    });

    testWidgets('updates profile information successfully', (WidgetTester tester) async {
      await tester.pumpWidget(createProfileScreen());
      await tester.pump();

      // Update name
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Jane Doe');
      await tester.pump();

      // Update age
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '30');
      await tester.pump();

      // Update gender
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Gender'));
      await tester.pump();
      await tester.tap(find.text('Female').last);
      await tester.pump();

      // Save profile
      await tester.tap(find.text('Save Profile'));
      await tester.pump();

      // Verify Firestore update was called with correct data
      verify(mockDocRef.set({
        'name': 'Jane Doe',
        'age': 30,
        'gender': 'Female',
        'email': 'john@example.com',
        'uid': 'test-uid',
        'walletBalance': 1000.0,
      })).called(1);

      // Verify success message
      expect(find.text('✅ Profile updated successfully'), findsOneWidget);
    });

    testWidgets('validates form fields correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createProfileScreen());
      await tester.pump();

      // Clear name field
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), '');
      await tester.pump();

      // Enter invalid age
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '150');
      await tester.pump();

      // Try to save
      await tester.tap(find.text('Save Profile'));
      await tester.pump();

      // Verify validation messages
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Enter a valid age'), findsOneWidget);

      // Verify Firestore update was not called
      verifyNever(mockDocRef.set(any));
    });
  });
} 