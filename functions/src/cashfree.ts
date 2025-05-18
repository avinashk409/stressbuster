import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface CashfreeWebhookData {
  orderId: string;
  orderAmount: number;
  orderCurrency: string;
  orderStatus: string;
  paymentMode: string;
  referenceId: string;
  signature: string;
  txStatus: string;
  txTime: string;
  txMsg: string;
}

export const cashfreeWebhook = functions.https.onRequest(async (request, response) => {
  try {
    // Verify request method
    if (request.method !== 'POST') {
      response.status(405).send('Method Not Allowed');
      return;
    }

    const webhookData = request.body as CashfreeWebhookData;
    const db = admin.firestore();

    // Verify webhook signature
    // TODO: Implement signature verification using Cashfree's documentation
    // https://docs.cashfree.com/docs/webhook-verification

    // Get the transaction document
    const transactionRef = db.collection('transactions').doc(webhookData.orderId);
    const transactionDoc = await transactionRef.get();

    if (!transactionDoc.exists) {
      console.error(`Transaction ${webhookData.orderId} not found`);
      response.status(404).send('Transaction not found');
      return;
    }

    const transactionData = transactionDoc.data();
    if (!transactionData) {
      console.error(`Transaction data is empty for ${webhookData.orderId}`);
      response.status(500).send('Transaction data is empty');
      return;
    }

    // Update transaction status
    await transactionRef.update({
      status: webhookData.orderStatus,
      paymentMode: webhookData.paymentMode,
      referenceId: webhookData.referenceId,
      txStatus: webhookData.txStatus,
      txTime: webhookData.txTime,
      txMsg: webhookData.txMsg,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // If payment is successful, update user's wallet and counselor's earnings
    if (webhookData.orderStatus === 'SUCCESS') {
      const userId = transactionData.userId;
      const counselorId = transactionData.counselorId;
      const amount = webhookData.orderAmount;

      // Update user's wallet
      const userRef = db.collection('users').doc(userId);
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw new Error('User not found');
        }

        const currentBalance = userDoc.data()?.walletBalance || 0;
        transaction.update(userRef, {
          walletBalance: currentBalance + amount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      // If this is a counselor payment, update counselor's earnings
      if (counselorId) {
        const counselorRef = db.collection('counselors').doc(counselorId);
        await db.runTransaction(async (transaction) => {
          const counselorDoc = await transaction.get(counselorRef);
          if (!counselorDoc.exists) {
            throw new Error('Counselor not found');
          }

          const currentEarnings = counselorDoc.data()?.totalEarnings || 0;
          transaction.update(counselorRef, {
            totalEarnings: currentEarnings + amount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Add to counselor's earnings history
          const earningRef = counselorRef.collection('earnings').doc();
          transaction.set(earningRef, {
            amount,
            orderId: webhookData.orderId,
            userId,
            status: webhookData.orderStatus,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      }
    }

    response.status(200).send('Webhook processed successfully');
  } catch (error) {
    console.error('Error processing webhook:', error);
    response.status(500).send('Internal Server Error');
  }
}); 