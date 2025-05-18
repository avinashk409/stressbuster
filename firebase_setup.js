const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setupCollections() {
  try {
    // 1. Create users collection with admin user
    const adminUser = {
      phoneNumber: "+919876543210", // Replace with your admin phone number
      role: "admin",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      name: "Admin User",
      email: "admin@stressbuster.com"
    };
    await db.collection('users').doc('admin').set(adminUser);
    console.log('Created users collection with admin user');

    // 2. Create otp_verifications collection
    const otpDoc = {
      otp: "123456",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000) // 10 minutes from now
    };
    await db.collection('otp_verifications').doc('+919876543210').set(otpDoc);
    console.log('Created otp_verifications collection');

    // 3. Create sessions collection
    const sessionDoc = {
      userId: "user1",
      counselorId: "counselor1",
      status: "scheduled",
      startTime: admin.firestore.FieldValue.serverTimestamp(),
      endTime: new Date(Date.now() + 60 * 60 * 1000), // 1 hour from now
      notes: "Initial session setup"
    };
    await db.collection('sessions').doc('session1').set(sessionDoc);
    console.log('Created sessions collection');

    // 4. Create counselor_earnings collection
    const earningsDoc = {
      totalEarnings: 0,
      pendingAmount: 0,
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp()
    };
    await db.collection('counselor_earnings').doc('counselor1').set(earningsDoc);
    console.log('Created counselor_earnings collection');

    // 5. Create reviews collection
    const reviewDoc = {
      userId: "user1",
      sessionId: "session1",
      rating: 5,
      comment: "Great session!",
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    await db.collection('reviews').doc('review1').set(reviewDoc);
    console.log('Created reviews collection');

    // 6. Create content collection
    const contentDoc = {
      title: "Welcome to StressBuster",
      content: "This is the first article in our platform.",
      type: "article",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    await db.collection('content').doc('welcome').set(contentDoc);
    console.log('Created content collection');

    // 7. Create settings collection
    const settingsDoc = {
      value: {
        appName: "StressBuster",
        version: "1.0.0",
        maintenanceMode: false
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    await db.collection('settings').doc('app_settings').set(settingsDoc);
    console.log('Created settings collection');

    console.log('All collections created successfully!');
  } catch (error) {
    console.error('Error setting up collections:', error);
  }
}

setupCollections(); 