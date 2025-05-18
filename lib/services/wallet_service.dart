import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  final dynamic _auth;
  final dynamic _firestore;

  WalletService({dynamic auth, dynamic firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get current wallet balance
  Future<double> getBalance() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0.0;

    final doc = await _firestore.collection('wallets').doc(uid).get();
    return (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// Add funds to wallet from Cashfree payment
  Future<void> addFunds(String userId, double amount) async {
    final walletRef = _firestore.collection('wallets').doc(userId);
    final txnRef = walletRef.collection('entries').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(walletRef);
      final currentBalance = (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance + amount;

      transaction.set(walletRef, {'balance': newBalance}, SetOptions(merge: true));
      transaction.set(txnRef, {
        'amount': amount,
        'type': 'recharge',
        'timestamp': FieldValue.serverTimestamp(),
        'note': 'Wallet recharge via Cashfree',
      });
    });
  }

  /// Update counselor's earnings from Cashfree payment
  Future<void> updateCounselorEarnings(String counselorId, double amount) async {
    final counselorRef = _firestore.collection('counselors').doc(counselorId);
    final earningsRef = counselorRef.collection('earnings').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counselorRef);
      final currentEarnings = (snapshot.data()?['totalEarnings'] as num?)?.toDouble() ?? 0.0;
      final newEarnings = currentEarnings + amount;

      transaction.set(counselorRef, {'totalEarnings': newEarnings}, SetOptions(merge: true));
      transaction.set(earningsRef, {
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'session_payment',
        'status': 'completed',
      });
    });
  }

  /// Add money to wallet (recharge)
  Future<void> addMoney(double amount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final walletRef = _firestore.collection('wallets').doc(uid);
    final txnRef = walletRef.collection('entries').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(walletRef);
      final currentBalance =
          (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance + amount;

      transaction.set(walletRef, {'balance': newBalance}, SetOptions(merge: true));
      transaction.set(txnRef, {
        'amount': amount,
        'type': 'recharge',
        'timestamp': FieldValue.serverTimestamp(),
        'note': 'Wallet recharge',
      });
    });
  }

  /// Deduct money from wallet (for paid services)
  Future<void> deductMoney(double amount, String note) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final walletRef = _firestore.collection('wallets').doc(uid);
    final txnRef = walletRef.collection('entries').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(walletRef);
      final currentBalance =
          (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < amount) {
        throw Exception("Insufficient balance");
      }

      final newBalance = currentBalance - amount;

      transaction.set(walletRef, {'balance': newBalance}, SetOptions(merge: true));
      transaction.set(txnRef, {
        'amount': amount,
        'type': 'debit',
        'timestamp': FieldValue.serverTimestamp(),
        'note': note,
      });
    });
  }

  /// Real-time stream of transactions
  Stream<QuerySnapshot> getTransactions() {
    final uid = _auth.currentUser?.uid;
    return _firestore
        .collection('wallets')
        .doc(uid)
        .collection('entries')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get total credits and debits in a given month (e.g. for reports)
  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {"credit": 0.0, "debit": 0.0};

    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);

    final querySnapshot = await _firestore
        .collection('wallets')
        .doc(uid)
        .collection('entries')
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThan: end)
        .get();

    double credit = 0.0;
    double debit = 0.0;

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final type = data['type'];

      if (type == 'recharge') {
        credit += amount;
      } else if (type == 'debit') {
        debit += amount;
      }
    }

    return {"credit": credit, "debit": debit};
  }
}
