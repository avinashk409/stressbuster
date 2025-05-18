/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// When a new user is created, set up their initial profile and wallet
exports.onUserCreated = onDocumentCreated("users/{userId}", async (event) => {
  const userId = event.params.userId;
  const userData = event.data.data();
  logger.info(`New user created: ${userId}`, userData);

  // Create wallet for the new user
  await db.collection("wallets").doc(userId).set({
    balance: 0.0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info(`Wallet created for user: ${userId}`);
});

// Set custom claims for counselor role
exports.setCounselorRole = onCall(async (request) => {
  // Check if request is authorized
  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const { targetUid } = request.data;
  
  try {
    // Only existing admins should be able to set counselor role
    const callerUid = request.auth.uid;
    const callerSnap = await db.collection('users').doc(callerUid).get();
    const callerData = callerSnap.data();
    const isAdmin = callerData && callerData.isAdmin === true;

    if (!isAdmin) {
      throw new Error("Not authorized to assign roles");
    }

    // Set custom claim
    await admin.auth().setCustomUserClaims(targetUid, { 
      role: 'counselor',
      isCounselor: true 
    });
    
    // Update user record
    await db.collection('users').doc(targetUid).update({
      role: 'counselor',
      isCounselor: true,
      isAvailable: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    logger.error("Error setting counselor role:", error);
    throw new Error(error.message);
  }
});

// Send notification when a new chat message is received
exports.onNewChatMessage = onDocumentCreated("chats/{messageId}", async (event) => {
  try {
    const message = event.data.data();
    const receiverId = message.receiverId;
    
    // Get receiver's FCM token from their user document
    const userDoc = await db.collection('users').doc(receiverId).get();
    const userData = userDoc.data();
    const fcmToken = userData && userData.fcmToken;
    
    if (!fcmToken) {
      logger.info(`No FCM token found for user ${receiverId}`);
      return;
    }

    // Get sender name
    const senderDoc = await db.collection('users').doc(message.senderId).get();
    const senderData = senderDoc.data();
    const senderName = senderData && senderData.name || "Someone";

    // Send notification
    const payload = {
      notification: {
        title: "New Message",
        body: `${senderName} sent you a message`,
        sound: "default"
      },
      data: {
        type: "chat",
        senderId: message.senderId,
      }
    };

    await admin.messaging().sendToDevice(fcmToken, payload);
    logger.info(`Notification sent to ${receiverId}`);
  } catch (error) {
    logger.error("Error sending notification:", error);
  }
});

// Create counselor profile when a user is assigned the counselor role
exports.setupCounselorProfile = onDocumentWritten("users/{userId}", async (event) => {
  const userId = event.params.userId;
  const userData = event.data.after.data();

  // Only proceed if user has counselor role or isCounselor flag
  if ((!userData || userData.role !== "counselor") && (!userData || userData.isCounselor !== true)) {
    return;
  }

  try {
    // Ensure user has all required counselor fields
    const updates = {};
    
    // Default values for counselor properties if they don't exist
    if (!userData.specialty) {
      updates.specialty = "General Counseling";
    }
    
    if (!userData.rating) {
      updates.rating = 4.5;
    }
    
    if (userData.available === undefined) {
      updates.available = true;
    }
    
    if (!userData.image && !userData.photoURL) {
      // Generate a default avatar if no image exists
      const name = userData.name || (userData.email && userData.email.split('@')[0]) || "Counselor";
      updates.image = `https://ui-avatars.com/api/?name=${name.replace(/\s+/g, "+")}&background=random`;
    }
    
    // Ensure isCounselor flag is set
    if (userData.isCounselor !== true) {
      updates.isCounselor = true;
    }
    
    // Only update if we have fields to change
    if (Object.keys(updates).length > 0) {
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      
      await db.collection('users').doc(userId).update(updates);
      logger.info(`Counselor profile updated for user: ${userId}`);
    }
  } catch (error) {
    logger.error("Error setting up counselor profile:", error);
  }
});

// Process wallet transaction with proper validation
exports.processWalletTransaction = onCall(async (request) => {
  // Ensure the user is authenticated
  if (!request.auth) {
    throw new Error("Authentication required");
  }

  const userId = request.auth.uid;
  const { amount, transactionType, note } = request.data;

  if (!amount || typeof amount !== "number" || amount <= 0) {
    throw new Error("Invalid amount");
  }

  if (transactionType !== "credit" && transactionType !== "debit") {
    throw new Error("Invalid transaction type");
  }

  try {
    const walletRef = db.collection('wallets').doc(userId);
    
    // Run in transaction to ensure data consistency
    return await db.runTransaction(async (transaction) => {
      const walletDoc = await transaction.get(walletRef);
      
      if (!walletDoc.exists) {
        throw new Error("Wallet not found");
      }
      
      const currentBalance = walletDoc.data().balance || 0;
      
      // For debit transactions, verify sufficient funds
      if (transactionType === "debit" && currentBalance < amount) {
        throw new Error("Insufficient funds");
      }
      
      // Calculate new balance
      const newBalance = transactionType === "credit" 
        ? currentBalance + amount 
        : currentBalance - amount;
      
      // Update wallet balance
      transaction.update(walletRef, { balance: newBalance });
      
      // Add transaction record
      const entryRef = walletRef.collection('entries').doc();
      transaction.set(entryRef, {
        amount: amount,
        type: transactionType === "credit" ? "recharge" : "debit",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        note: note || (transactionType === "credit" ? "Wallet recharge" : "Service payment")
      });
      
      return { success: true, newBalance };
    });
  } catch (error) {
    logger.error("Transaction error:", error);
    throw new Error(error.message);
  }
});

// One-time function to set specific users as admins
exports.setInitialAdmins = onRequest(async (request, response) => {
  try {
    // Only allow this function to be called in development or with a secret key
    const secretKey = request.query.key;
    if (secretKey !== 'stressbuster_admin_setup_2023') {
      response.status(403).send('Unauthorized');
      return;
    }
    
    // Users to be set as admins - add your user ID here
    const adminUsers = ['jDHLz1yFk0UpSJeM0dTLVGRt5T83'];
    
    for (const userId of adminUsers) {
      // Update user document
      await db.collection('users').doc(userId).update({
        isAdmin: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Set custom claim to make this user an admin
      await admin.auth().setCustomUserClaims(userId, { 
        admin: true,
        role: 'admin'
      });
      
      logger.info(`User ${userId} has been set as admin`);
    }
    
    response.send(`Admin privileges set for ${adminUsers.length} user(s)`);
  } catch (error) {
    logger.error("Error setting admin status:", error);
    response.status(500).send(`Error: ${error.message}`);
  }
});

// Cloud function to update existing counselors with the isCounselor field
exports.updateExistingCounselors = onRequest(async (request, response) => {
  try {
    // Only allow this function to be called with a secret key
    const secretKey = request.query.key;
    if (secretKey !== 'stressbuster_admin_setup_2023') {
      response.status(403).send('Unauthorized');
      return;
    }
    
    // 1. Get all documents from the counselors collection
    const counselorSnap = await db.collection('counselors').get();
    
    if (counselorSnap.empty) {
      response.send('No existing counselors found');
      return;
    }
    
    const batch = db.batch();
    let updatedCount = 0;
    
    // 2. For each counselor, update their user document with isCounselor=true
    for (const doc of counselorSnap.docs) {
      const counselorId = doc.id;
      
      try {
        // Update the user document
        const userDocRef = db.collection('users').doc(counselorId);
        const userDoc = await userDocRef.get();
        
        if (userDoc.exists) {
          batch.update(userDocRef, { 
            'isCounselor': true,
            'updatedAt': admin.firestore.FieldValue.serverTimestamp()
          });
          updatedCount++;
        } else {
          logger.info(`User document for counselor ${counselorId} not found`);
        }
      } catch (error) {
        logger.error(`Error updating user ${counselorId}: ${error.message}`);
      }
      
      // Commit in batches of 500 to avoid hitting Firestore limits
      if (updatedCount > 0 && updatedCount % 500 === 0) {
        await batch.commit();
        batch = db.batch(); // Reset batch
      }
    }
    
    // Commit any remaining updates
    if (updatedCount % 500 !== 0) {
      await batch.commit();
    }
    
    response.send(`Successfully updated ${updatedCount} counselor accounts with isCounselor=true`);
  } catch (error) {
    logger.error("Error updating counselors:", error);
    response.status(500).send(`Error: ${error.message}`);
  }
});

// Migrate existing counselor data to user documents
exports.migrateCounselorData = onRequest(async (request, response) => {
  try {
    // Only allow this function to be called with a secret key
    const secretKey = request.query.key;
    if (secretKey !== 'stressbuster_admin_setup_2023') {
      response.status(403).send('Unauthorized');
      return;
    }
    
    // Get all counselor documents
    const counselorSnap = await db.collection('counselors').get();
    
    if (counselorSnap.empty) {
      response.send('No counselors to migrate');
      return;
    }
    
    let migratedCount = 0;
    let errorCount = 0;
    
    // Process each counselor document
    for (const doc of counselorSnap.docs) {
      try {
        const counselorId = doc.id;
        const counselorData = doc.data();
        
        // Get the corresponding user document
        const userRef = db.collection('users').doc(counselorId);
        const userDoc = await userRef.get();
        
        if (userDoc.exists) {
          // Update the user document with counselor data
          await userRef.update({
            isCounselor: true,
            role: 'counselor',
            name: counselorData.name || userDoc.data().name,
            specialty: counselorData.specialty || 'General Counseling',
            rating: counselorData.rating || 4.5,
            available: counselorData.available !== undefined ? counselorData.available : true,
            image: counselorData.image || userDoc.data().photoURL,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          migratedCount++;
          logger.info(`Migrated counselor data for user ${counselorId}`);
        } else {
          logger.error(`User document not found for counselor ${counselorId}`);
          errorCount++;
        }
      } catch (error) {
        logger.error(`Error migrating counselor ${doc.id}: ${error.message}`);
        errorCount++;
      }
    }
    
    response.send(`Migration completed: ${migratedCount} counselors migrated, ${errorCount} errors`);
  } catch (error) {
    logger.error("Error during counselor migration:", error);
    response.status(500).send(`Error: ${error.message}`);
  }
});

// Toggle counselor availability
exports.toggleCounselorAvailability = onCall(async (request) => {
  // Check if request is authorized
  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const userId = request.auth.uid;
  const { newStatus } = request.data;
  
  try {
    // Verify user is a counselor
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData || userData.isCounselor !== true) {
      throw new Error("Only counselors can toggle availability");
    }

    // Update user's availability status
    await db.collection('users').doc(userId).update({
      isAvailable: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { 
      success: true, 
      status: newStatus 
    };
  } catch (error) {
    logger.error("Error toggling counselor availability:", error);
    throw new Error(error.message);
  }
});
