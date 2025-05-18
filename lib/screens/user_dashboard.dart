import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserDashboard extends StatefulWidget {
  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _bookSession(String counselorId, String counselorName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Create a new session document
      await _firestore.collection('sessions').add({
        'userId': user.uid,
        'counselorId': counselorId,
        'counselorName': counselorName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledAt': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session request sent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking session: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Counselors',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .where('role', isEqualTo: 'counselor')
                        .where('isAvailable', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final counselors = snapshot.data?.docs ?? [];

                      if (counselors.isEmpty) {
                        return Center(
                          child: Text('No counselors available at the moment'),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: counselors.length,
                        itemBuilder: (context, index) {
                          final counselor = counselors[index].data() as Map<String, dynamic>;
                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(counselor['name']?[0] ?? 'C'),
                              ),
                              title: Text(counselor['name'] ?? 'Unknown Counselor'),
                              subtitle: Text(counselor['specialization'] ?? 'General Counseling'),
                              trailing: ElevatedButton(
                                onPressed: () => _bookSession(
                                  counselors[index].id,
                                  counselor['name'] ?? 'Unknown Counselor',
                                ),
                                child: Text('Book Session'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Your Sessions',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('sessions')
                        .where('userId', isEqualTo: _auth.currentUser?.uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final sessions = snapshot.data?.docs ?? [];

                      if (sessions.isEmpty) {
                        return Center(
                          child: Text('No sessions booked yet'),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index].data() as Map<String, dynamic>;
                          final createdAt = session['createdAt'] as Timestamp?;
                          final scheduledAt = session['scheduledAt'] as Timestamp?;

                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              title: Text('Session with ${session['counselorName']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Status: ${session['status']}'),
                                  if (createdAt != null)
                                    Text('Booked on: ${DateFormat('MMM d, y').format(createdAt.toDate())}'),
                                  if (scheduledAt != null)
                                    Text('Scheduled for: ${DateFormat('MMM d, y HH:mm').format(scheduledAt.toDate())}'),
                                ],
                              ),
                              trailing: Icon(
                                _getStatusIcon(session['status']),
                                color: _getStatusColor(session['status']),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 