import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'package:stressbuster/widgets/image_widget.dart';
import 'package:url_launcher/url_launcher.dart';

// Adding SessionCard class implementation
class SessionCard extends StatelessWidget {
  final Map<String, dynamic> sessionData;
  final String sessionId;
  final VoidCallback onRefresh;

  const SessionCard({
    Key? key,
    required this.sessionData,
    required this.sessionId,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = sessionData['userId'] ?? '';
    final scheduledDateTime = sessionData['scheduledDateTime'] as Timestamp?;
    final status = sessionData['status'] ?? 'scheduled';
    final sessionType = sessionData['sessionType'] ?? 'chat';
    final cost = sessionData['cost'] ?? 0.0;
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        String userName = 'User';
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          userName = userData['name'] ?? userData['email']?.toString().split('@')[0] ?? 'User';
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Session with $userName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'scheduled' ? Colors.blue :
                               status == 'completed' ? Colors.green :
                               Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (scheduledDateTime != null)
                  Text(
                    'Scheduled for: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDateTime.toDate())}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      sessionType == 'video' ? Icons.videocam : Icons.chat,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sessionType == 'video' ? 'Video Session' : 'Chat Session',
                      style: const TextStyle(color: Colors.blue),
                    ),
                    const Spacer(),
                    Text(
                      '₹${cost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (status == 'scheduled') ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _cancelSession(context),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(sessionType == 'video' ? Icons.videocam : Icons.chat),
                        label: Text(sessionType == 'video' ? 'Join Video' : 'Start Chat'),
                        onPressed: () => _joinSession(context, sessionType),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _cancelSession(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session'),
        content: const Text('Are you sure you want to cancel this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionId)
            .update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });
            
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session cancelled successfully')),
        );
        
        onRefresh();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling session: $e')),
        );
      }
    }
  }
  
  void _joinSession(BuildContext context, String type) {
    if (type == 'video') {
      // Navigate to video call screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video call functionality will be implemented soon')),
      );
    } else {
      // Navigate to chat screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat functionality will be implemented soon')),
      );
    }
  }
}

class CounselorDashboard extends StatefulWidget {
  const CounselorDashboard({Key? key}) : super(key: key);

  @override
  _CounselorDashboardState createState() => _CounselorDashboardState();
}

class _CounselorDashboardState extends State<CounselorDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currentUser = FirebaseAuth.instance.currentUser;
  bool isAvailable = false;
  bool isLoading = true;
  double earnings = 0.0;
  double pendingWithdrawal = 0.0;
  String _counselorName = '';
  double _totalEarnings = 0.0;
  double _availableBalance = 0.0;
  String? _profileImage;
  bool _isOnline = false;
  
  // Link to create Firestore indexes
  final Map<String, String> _indexLinks = {
    "scheduled_sessions_by_userId": "https://console.firebase.google.com/v1/r/project/stressbuster-30793/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zdHJlc3NidXN0ZXItMzA3OTMvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3Nlc3Npb25zL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGgoKBnVzZXJJZBABGg8KC3NjaGVkdWxlZEF0EAEaDAoIX19uYW1lX18QAQ",
    "scheduled_sessions_by_counselorId": "https://console.firebase.google.com/v1/r/project/stressbuster-30793/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zdHJlc3NidXN0ZXItMzA3OTMvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3Nlc3Npb25zL2luZGV4ZXMvXxABGg8KC2NvdW5zZWxvcklkEAEaCgoGc3RhdHVzEAEaFQoRc2NoZWR1bGVkRGF0ZVRpbWUQARoMCghfX25hbWVfXxAB"
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCounselorData();
    _loadCounselorProfile();
    _loadCounselorEarnings();
    _updateOnlineStatus(true);
  }
  
  Future<void> _loadCounselorData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          isAvailable = userData['isAvailable'] ?? false;
          earnings = (userData['earnings'] ?? 0.0).toDouble();
          isLoading = false;
        });
      }
      
      // Get pending withdrawal amount
      final withdrawalQuery = await FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .where('counselorId', isEqualTo: currentUser?.uid)
          .where('status', isEqualTo: 'pending')
          .get();
          
      double pendingAmount = 0.0;
      for (var doc in withdrawalQuery.docs) {
        pendingAmount += (doc.data()['amount'] ?? 0.0).toDouble();
      }
      
      setState(() {
        pendingWithdrawal = pendingAmount;
      });
    } catch (e) {
      debugPrint('Error loading counselor data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  Future<void> _loadCounselorProfile() async {
    if (currentUser == null) return;
    
    try {
      // Check user document instead of counselors collection
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
          
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          isAvailable = data['isAvailable'] ?? true;
          _counselorName = data['name'] ?? data['email']?.toString().split('@')[0] ?? 'Counselor';
          _profileImage = data['image'] ?? data['photoURL'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error loading counselor profile: $e');
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _loadCounselorEarnings() async {
    if (currentUser == null) return;
    
    try {
      // Get completed sessions
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('counselorId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .get();
          
      double total = 0.0;
      
      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        total += (data['cost'] ?? 0.0);
      }
      
      // Get earnings document
      final earningsDoc = await FirebaseFirestore.instance
          .collection('counselor_earnings')
          .doc(currentUser!.uid)
          .get();
          
      if (earningsDoc.exists) {
        final data = earningsDoc.data()!;
        setState(() {
          _totalEarnings = total;
          _availableBalance = data['available_balance'] ?? total;
        });
      } else {
        // Create earnings document if it doesn't exist
        await FirebaseFirestore.instance
            .collection('counselor_earnings')
            .doc(currentUser!.uid)
            .set({
              'total_earnings': total,
              'available_balance': total,
              'last_updated': FieldValue.serverTimestamp()
            });
            
        setState(() {
          _totalEarnings = total;
          _availableBalance = total;
        });
      }
    } catch (e) {
      print('Error loading earnings: $e');
    }
  }
  
  Future<void> _toggleAvailability() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Ensure user is authenticated
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Toggle the availability status
      final newStatus = !isAvailable;
      
      // First check if user is a counselor
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
          
      if (!userDoc.exists || userDoc.data()?['isCounselor'] != true) {
        throw Exception('Only counselors can change availability');
      }
      
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
            'isAvailable': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      setState(() {
        isAvailable = newStatus;
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are now ${newStatus ? 'available' : 'unavailable'} for sessions'),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Unable to update status. ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  Future<void> _requestWithdrawal() async {
    if (earnings <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have no earnings to withdraw'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (pendingWithdrawal > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have a pending withdrawal request'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final accountNumberController = TextEditingController();
    final ifscCodeController = TextEditingController();
    final accountNameController = TextEditingController();
    final amountController = TextEditingController(text: earnings.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Withdrawal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Account Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ifscCodeController,
                decoration: const InputDecoration(
                  labelText: 'IFSC Code',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: accountNameController,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate inputs
              if (accountNumberController.text.isEmpty ||
                  ifscCodeController.text.isEmpty ||
                  accountNameController.text.isEmpty ||
                  amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              double amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0 || amount > earnings) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Submit withdrawal request
              await FirebaseFirestore.instance
                  .collection('withdrawal_requests')
                  .add({
                    'counselorId': currentUser?.uid,
                    'amount': amount,
                    'status': 'pending',
                    'created_at': FieldValue.serverTimestamp(),
                    'bankDetails': {
                      'accountNumber': accountNumberController.text,
                      'ifscCode': ifscCodeController.text,
                      'accountName': accountNameController.text,
                    }
                  });
              
              Navigator.pop(context);
              
              // Refresh data
              _loadCounselorData();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Withdrawal request submitted. The admin will process it soon.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counselor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sessions'),
            Tab(text: 'Earnings'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSessionsTab(),
                _buildEarningsTab(),
              ],
            ),
    );
  }
  
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Availability Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Your Availability Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle : Icons.cancel,
                        color: isAvailable ? Colors.green : Colors.red,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isAvailable ? 'You are AVAILABLE' : 'You are UNAVAILABLE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(isAvailable ? Icons.cancel : Icons.check_circle),
                      label: Text(isAvailable ? 'Go Unavailable' : 'Go Available'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAvailable ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _toggleAvailability,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Stats Cards
          Row(
            children: [
              // Earnings Card
              Expanded(
                child: _buildStatCard(
                  title: 'Earnings',
                  value: '₹${earnings.toStringAsFixed(2)}',
                  icon: Icons.payments,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              // Pending Card
              Expanded(
                child: _buildStatCard(
                  title: 'Pending Withdrawal',
                  value: '₹${pendingWithdrawal.toStringAsFixed(2)}',
                  icon: Icons.history,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Upcoming Sessions
          const Text(
            'Upcoming Sessions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sessions')
                .where('counselorId', isEqualTo: currentUser?.uid)
                .where('status', isEqualTo: 'scheduled')
                .orderBy('scheduledDateTime', descending: false)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No upcoming sessions',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              final sessions = snapshot.data!.docs;
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final sessionData = sessions[index].data() as Map<String, dynamic>;
                  final sessionId = sessions[index].id;
                  
                  return SessionCard(
                    sessionData: sessionData,
                    sessionId: sessionId,
                    onRefresh: () => setState(() {}),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSessionsTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Scheduled'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSessionsList('scheduled'),
                _buildSessionsList('completed'),
                _buildSessionsList('cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSessionsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('counselorId', isEqualTo: currentUser?.uid)
          .where('status', isEqualTo: status)
          .orderBy('scheduledDateTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'scheduled' ? Icons.event_busy :
                  status == 'completed' ? Icons.event_available :
                  Icons.event_busy,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No $status sessions found',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        final sessions = snapshot.data!.docs;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final sessionData = sessions[index].data() as Map<String, dynamic>;
            final sessionId = sessions[index].id;
            
            return SessionCard(
              sessionData: sessionData,
              sessionId: sessionId,
              onRefresh: () => setState(() {}),
            );
          },
        );
      },
    );
  }
  
  Widget _buildEarningsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Earnings Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Balance',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${earnings.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('Withdraw'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: earnings > 0 ? _requestWithdrawal : null,
                      ),
                    ],
                  ),
                  if (pendingWithdrawal > 0) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.hourglass_bottom, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Pending Withdrawal: ₹${pendingWithdrawal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Transaction history
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sessions')
                .where('counselorId', isEqualTo: currentUser?.uid)
                .where('status', isEqualTo: 'completed')
                .orderBy('completedAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              final sessions = snapshot.data!.docs;
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final sessionData = sessions[index].data() as Map<String, dynamic>;
                  final sessionId = sessions[index].id;
                  
                  final amount = sessionData['amount'] ?? 0.0;
                  final completedAt = sessionData['completedAt'] as Timestamp?;
                  final userId = sessionData['userId'] ?? '';
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, userSnapshot) {
                      String userName = 'Unknown User';
                      
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        userName = userData['name'] ?? 'User';
                      }
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.payments, color: Colors.white),
                          ),
                          title: Text('Session with $userName'),
                          subtitle: Text(
                            completedAt != null
                                ? _formatDate(completedAt.toDate())
                                : 'Date unknown',
                          ),
                          trailing: Text(
                            '+₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Withdrawal history
          const Text(
            'Withdrawal History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('withdrawal_requests')
                .where('counselorId', isEqualTo: currentUser?.uid)
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No withdrawal requests yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              final requests = snapshot.data!.docs;
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final requestData = requests[index].data() as Map<String, dynamic>;
                  
                  final amount = requestData['amount'] ?? 0.0;
                  final status = requestData['status'] ?? 'pending';
                  final timestamp = requestData['created_at'] as Timestamp?;
                  final processedAt = requestData['processed_at'] as Timestamp?;
                  
                  Color statusColor;
                  IconData statusIcon;
                  
                  switch (status) {
                    case 'completed':
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      break;
                    case 'rejected':
                      statusColor = Colors.red;
                      statusIcon = Icons.cancel;
                      break;
                    default:
                      statusColor = Colors.orange;
                      statusIcon = Icons.hourglass_bottom;
                  }
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.2),
                        child: Icon(statusIcon, color: statusColor),
                      ),
                      title: Text('Withdrawal Request'),
                      subtitle: Text(
                        timestamp != null
                            ? 'Requested: ${_formatDate(timestamp.toDate())}'
                            : 'Date unknown',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    _updateOnlineStatus(false);
    _tabController.dispose();
    super.dispose();
  }
  
  // Update counselor online status
  Future<void> _updateOnlineStatus(bool isOnline) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isOnline = isOnline;
        });
        print('Counselor online status updated to: $isOnline');
      }
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  Future<void> _openIndexCreationPage(String indexKey) async {
    final String? url = _indexLinks[indexKey];
    if (url != null) {
      try {
        await launchUrl(Uri.parse(url));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open URL: $e')),
        );
      }
    }
  }
}