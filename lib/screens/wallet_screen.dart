import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/wallet_service.dart';
import 'cashfree_payment_screen.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  double _balance = 0.0;
  bool _loading = true;

  final currencyFormatter = NumberFormat.simpleCurrency(locale: 'en_IN');
  final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await _walletService.getBalance();
    setState(() {
      _balance = balance;
      _loading = false;
    });
  }

  void _navigateToPaymentScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CashfreePaymentScreen(
          amount: 0.0, // This will be editable in the payment screen
          purpose: 'wallet_recharge',
        ),
      ),
    );
    
    if (result != null && result is double) {
      await _loadBalance(); // refresh balance
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Wallet")),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBalance,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Balance Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Available Balance",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              currencyFormatter.format(_balance),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: Icon(Icons.add),
                              label: Text("Add Money"),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.teal,
                              ),
                              onPressed: _navigateToPaymentScreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    
                    // Transaction Categories
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTransactionCategory(
                          "All",
                          Icons.list_alt,
                          isSelected: true,
                        ),
                        _buildTransactionCategory(
                          "Recharge",
                          Icons.add_circle_outline,
                        ),
                        _buildTransactionCategory(
                          "Sessions",
                          Icons.video_call_outlined,
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 30),
                    Text(
                      "Recent Transactions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),

                    /// Transaction List
                    LimitedBox(
                      maxHeight: 500,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _walletService.getTransactions(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "No transactions yet.",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Add money to your wallet to get started.",
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final transactions = snapshot.data!.docs;

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: transactions.length,
                            separatorBuilder: (context, index) => Divider(),
                            itemBuilder: (context, index) {
                              final txn = transactions[index].data() as Map<String, dynamic>;
                              final amount = txn['amount'] ?? 0.0;
                              final type = txn['type'] ?? 'unknown';
                              final note = txn['note'] ?? '';
                              final timestamp = txn['timestamp'] != null
                                  ? (txn['timestamp'] as Timestamp).toDate()
                                  : DateTime.now();

                              final isRecharge = type == 'recharge';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isRecharge
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  child: Icon(
                                    isRecharge ? Icons.add : Icons.remove,
                                    color: isRecharge ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  isRecharge ? "Wallet Recharge" : note,
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(dateFormatter.format(timestamp)),
                                trailing: Text(
                                  "${isRecharge ? "+" : "-"}${currencyFormatter.format(amount)}",
                                  style: TextStyle(
                                    color: isRecharge ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildTransactionCategory(String label, IconData icon, {bool isSelected = false}) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.teal : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.teal : Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.teal : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
