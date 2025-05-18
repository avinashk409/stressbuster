import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stressbuster/widgets/image_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'counselor_list_screen.dart';
import 'call_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? userName;
  bool _isLoading = true;
  final List<String> _stressTips = [
    "Take deep breaths to calm your nervous system",
    "Practice mindfulness for 5 minutes daily",
    "Take short breaks during work to stretch",
    "Ensure you're getting 7-8 hours of sleep",
    "Reduce caffeine intake if feeling anxious",
    "Try progressive muscle relaxation techniques",
    "Connect with loved ones when feeling overwhelmed",
    "Physical activity can help reduce stress levels",
    "Keep a journal to track stress triggers",
    "Limit screen time before bedtime"
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Link to create Firestore indexes
  final Map<String, String> _indexLinks = {
    "scheduled_sessions_by_userId": "https://console.firebase.google.com/v1/r/project/stressbuster-30793/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zdHJlc3NidXN0ZXItMzA3OTMvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3Nlc3Npb25zL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGgoKBnVzZXJJZBABGg8KC3NjaGVkdWxlZEF0EAEaDAoIX19uYW1lX18QAQ",
    "scheduled_sessions_by_counselorId": "https://console.firebase.google.com/v1/r/project/stressbuster-30793/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zdHJlc3NidXN0ZXItMzA3OTMvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3Nlc3Npb25zL2luZGV4ZXMvXxABGg8KC2NvdW5zZWxvcklkEAEaCgoGc3RhdHVzEAEaFQoRc2NoZWR1bGVkRGF0ZVRpbWUQARoMCghfX25hbWVfXxAB"
  };

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        final doc = await firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['name'] != null && data['name'].toString().trim().isNotEmpty) {
            setState(() {
              userName = data['name'];
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user name: $e');
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: true);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to continue'),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Welcome"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () async {
              try {
                await authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              } catch (e) {
                print('Error signing out: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Background image from assets
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/stress_relief.png"),
                      fit: BoxFit.cover,
                      alignment: Alignment(0.0, 0.4),
                    ),
                  ),
                ),

                // Transparent dark overlay
                Container(
                  color: Colors.black.withOpacity(0.3),
                ),

                // Main content
                SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (userName != null) ...[
                            Text(
                              "Hello,",
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              userName!,
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 30),
                          ] else
                            const SizedBox(height: 60),

                          // Stress tip of the day
                          Card(
                            elevation: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: Colors.teal.withOpacity(0.9),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.tips_and_updates, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Tip of the Day",
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _stressTips[DateTime.now().day % _stressTips.length],
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Upcoming sessions
                          if (user != null) ...[
                            Card(
                              elevation: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: Colors.white.withOpacity(0.95),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Upcoming Sessions",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 150,
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('sessions')
                                            .where('userId', isEqualTo: user.uid)
                                            .where('status', isEqualTo: 'scheduled')
                                            .orderBy('scheduledAt')
                                            .limit(3)
                                            .snapshots(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return Center(child: CircularProgressIndicator());
                                          }
                                          
                                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                            return Center(
                                              child: Text(
                                                "No upcoming sessions",
                                                style: GoogleFonts.poppins(),
                                              ),
                                            );
                                          }
                                          
                                          return ListView.builder(
                                            itemCount: snapshot.data!.docs.length,
                                            itemBuilder: (context, index) {
                                              final session = snapshot.data!.docs[index];
                                              final data = session.data() as Map<String, dynamic>;
                                              
                                              final counselorId = data['counselorId'] ?? '';
                                              final scheduledAt = data['scheduledAt'] as Timestamp?;
                                              final duration = data['duration'] ?? 30;
                                              
                                              if (scheduledAt == null) {
                                                return SizedBox.shrink();
                                              }
                                              
                                              final formatter = DateFormat('E, MMM d • h:mm a');
                                              final formattedDate = formatter.format(scheduledAt.toDate());
                                              
                                              return FutureBuilder<DocumentSnapshot>(
                                                future: FirebaseFirestore.instance
                                                    .collection('counselors')
                                                    .doc(counselorId)
                                                    .get(),
                                                builder: (context, counselorSnapshot) {
                                                  String counselorName = 'Counselor';
                                                  
                                                  if (counselorSnapshot.hasData && counselorSnapshot.data!.exists) {
                                                    final counselorData = counselorSnapshot.data!.data() as Map<String, dynamic>;
                                                    counselorName = counselorData['name'] ?? 'Counselor';
                                                  }
                                                  
                                                  // Check if session is within 15 minutes
                                                  final now = DateTime.now();
                                                  final sessionTime = scheduledAt.toDate();
                                                  final difference = sessionTime.difference(now);
                                                  final canJoin = difference.inMinutes <= 15 && difference.inMinutes >= -30;
                                                  
                                                  final roomName = "calmmind_${counselorName.replaceAll(" ", "_")}";
                                                  
                                                  return Card(
                                                    elevation: 2,
                                                    margin: EdgeInsets.symmetric(vertical: 4),
                                                    child: ListTile(
                                                      title: Text(
                                                        "Session with $counselorName",
                                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                                      ),
                                                      subtitle: Text(
                                                        "$formattedDate • $duration min",
                                                        style: GoogleFonts.poppins(fontSize: 12),
                                                      ),
                                                      trailing: canJoin
                                                          ? ElevatedButton(
                                                              onPressed: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) => CallScreen(
                                                                      roomCode: roomName,
                                                                      userName: userName ?? "User",
                                                                      isAudioOnly: false,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              child: Text("Join"),
                                                            )
                                                          : Text(
                                                              difference.inMinutes > 15
                                                                  ? "${(difference.inMinutes / 60).floor()}h ${difference.inMinutes % 60}m"
                                                                  : difference.inMinutes < -30
                                                                      ? "Missed"
                                                                      : "Soon",
                                                              style: GoogleFonts.poppins(
                                                                color: difference.inMinutes < 0 ? Colors.red : Colors.blue,
                                                                fontWeight: FontWeight.bold,
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
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Main menu items
                          _buildMenuItem(
                            context,
                            icon: Icons.account_balance_wallet,
                            label: "My Wallet",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => WalletScreen()),
                              );
                            },
                          ),
                          _buildMenuItem(
                            context,
                            icon: Icons.person,
                            label: "My Profile",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ProfileScreen()),
                              );
                            },
                            // Hidden admin setup
                            onLongPress: user?.uid == 'jDHLz1yFk0UpSJeM0dTLVGRt5T83' ? () async {
                              try {
                                // Create the document if it doesn't exist first
                                final docRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
                                final doc = await docRef.get();
                                
                                if (!doc.exists) {
                                  await docRef.set({
                                    'email': user.email,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                                }
                                
                                // Display admin activation info
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Admin activation: Please use the Firebase console to set isAdmin=true for this account or deploy the setInitialAdmins cloud function.'))
                                );
                                
                                // Show a dialog with instructions
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Admin Activation'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Your user ID:'),
                                        SelectableText(user.uid),
                                        SizedBox(height: 20),
                                        Text('To activate admin privileges:'),
                                        SizedBox(height: 10),
                                        Text('1. Go to Firebase Console > Firestore'),
                                        Text('2. Find your user document in the users collection'),
                                        Text('3. Add field: isAdmin = true (boolean)'),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'))
                                );
                              }
                            } : null,
                          ),
                          _buildMenuItem(
                            context,
                            icon: Icons.support_agent,
                            label: "Talk to Counselor",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => CounselorListScreen()),
                              );
                            },
                          ),
                          // Admin Panel menu item
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user?.uid)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data?.exists == true) {
                                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                final isAdmin = userData?['isAdmin'] == true;
                                
                                if (isAdmin) {
                                  return _buildMenuItem(
                                    context,
                                    icon: Icons.admin_panel_settings,
                                    label: "Admin Panel",
                                    onTap: () {
                                      Navigator.pushNamed(context, '/admin');
                                    },
                                  );
                                }
                              }
                              
                              return SizedBox.shrink(); // Not an admin, don't show the menu item
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white.withOpacity(0.95),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.teal),
          ),
          title: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }
}
