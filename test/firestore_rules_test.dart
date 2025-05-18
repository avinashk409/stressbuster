import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'firebase_test_config.dart';

void main() {
  late FirebaseFirestore firestore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: FirebaseTestConfig.options,
    );
    firestore = FirebaseFirestore.instance;
  });

  group('User Collection Rules', () {
    test('Users can read any user profile', () async {
      // Create a test user
      await firestore.collection('users').doc('testUser').set({
        'role': 'user',
        'name': 'Test User',
        'email': 'test@example.com'
      });

      // Try to read the user profile
      final doc = await firestore.collection('users').doc('testUser').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['role'], equals('user'));
    });

    test('Users can only update their own profile with allowed fields', () async {
      // Create a test user
      await firestore.collection('users').doc('testUser').set({
        'role': 'user',
        'name': 'Test User',
        'email': 'test@example.com',
        'walletBalance': 1000.0
      });

      // Try to update the profile with allowed fields
      await firestore.collection('users').doc('testUser').update({
        'name': 'Updated Name',
        'email': 'updated@example.com',
        'walletBalance': 1500.0
      });

      // Verify the update
      final doc = await firestore.collection('users').doc('testUser').get();
      expect(doc.data()?['name'], equals('Updated Name'));
      expect(doc.data()?['email'], equals('updated@example.com'));
      expect(doc.data()?['walletBalance'], equals(1500.0));
    });

    test('Users cannot update other users profiles', () async {
      // Create another test user
      await firestore.collection('users').doc('otherUser').set({
        'role': 'user',
        'name': 'Other User',
        'email': 'other@example.com'
      });

      // Try to update another user's profile
      expect(
        () => firestore.collection('users').doc('otherUser').update({
          'name': 'Hacked Name'
        }),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('Appointments Collection Rules', () {
    test('Users can read their own appointments', () async {
      // Create a test appointment
      await firestore.collection('appointments').doc('testAppointment').set({
        'userId': 'testUser',
        'counselorId': 'testCounselor',
        'status': 'scheduled',
        'notes': 'Test appointment'
      });

      // Try to read the appointment
      final doc = await firestore.collection('appointments').doc('testAppointment').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['userId'], equals('testUser'));
    });

    test('Counselors can read all appointments', () async {
      // Create a test counselor
      await firestore.collection('users').doc('testCounselor').set({
        'role': 'counselor',
        'name': 'Test Counselor',
        'email': 'counselor@example.com'
      });

      // Try to read appointments
      final query = await firestore.collection('appointments').get();
      expect(query.docs.isNotEmpty, isTrue);
    });

    test('Users can create appointments', () async {
      // Try to create an appointment
      final docRef = await firestore.collection('appointments').add({
        'userId': 'testUser',
        'counselorId': 'testCounselor',
        'status': 'scheduled',
        'notes': 'New appointment'
      });

      expect(docRef.id, isNotEmpty);
    });
  });

  // Clean up after tests
  tearDownAll(() async {
    // Delete test data
    await firestore.collection('users').doc('testUser').delete();
    await firestore.collection('users').doc('otherUser').delete();
    await firestore.collection('users').doc('testCounselor').delete();
    await firestore.collection('appointments').doc('testAppointment').delete();
  });
} 