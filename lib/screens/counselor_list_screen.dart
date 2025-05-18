import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'call_screen.dart';
import 'chat_screen.dart';
import '../services/wallet_service.dart';

class CounselorListScreen extends StatefulWidget {
  @override
  State<CounselorListScreen> createState() => _CounselorListScreenState();
}

class _CounselorListScreenState extends State<CounselorListScreen> {
  bool isAudioOnly = false;
  final WalletService _walletService = WalletService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Counselors"),
        actions: [
          Row(
            children: [
              Icon(isAudioOnly ? Icons.headset_mic : Icons.videocam),
              Switch(
                value: isAudioOnly,
                onChanged: (value) {
                  setState(() => isAudioOnly = value);
                },
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
          .collection('users')
          .where('isCounselor', isEqualTo: true)
          .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No counselors available."));
          }

          final counselors = snapshot.data!.docs;
          
          // Sort counselors: online first, then offline
          final sortedCounselors = List.from(counselors);
          sortedCounselors.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            final aIsOnline = aData['isOnline'] ?? false;
            final bIsOnline = bData['isOnline'] ?? false;
            
            if (aIsOnline && !bIsOnline) return -1;
            if (!aIsOnline && bIsOnline) return 1;
            return 0;
          });

          return ListView.builder(
            itemCount: sortedCounselors.length,
            itemBuilder: (context, index) {
              final data = sortedCounselors[index].data() as Map<String, dynamic>;
              final counselorId = sortedCounselors[index].id;
              return _buildCounselorCard(data, counselorId);
            },
          );
        },
      ),
    );
  }

  Widget _buildCounselorCard(Map<String, dynamic> data, String counselorId) {
    final name = data['name'] ?? data['email']?.toString().split('@')[0] ?? "Counselor";
    final specialty = data['specialty'] ?? "General Counseling";
    final image = data['image'] ?? data['photoURL'] ?? "https://ui-avatars.com/api/?name=${name.replaceAll(" ", "+")}&background=random";
    final isOnline = data['isOnline'] ?? false;
    final rating = data['rating']?.toDouble() ?? 4.5; // Default rating

    final roomName = "calmmind_${name.replaceAll(" ", "_")}";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(image),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.circle,
                          color: isOnline ? Colors.green : Colors.red,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Text(specialty),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.chat,
                  label: "Chat",
                  color: Colors.teal,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          counselorName: name,
                          counselorId: counselorId,
                        ),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.video_call,
                  label: "Call Now",
                  color: Colors.blue,
                  onPressed: isOnline ? () => _initiateCall(counselorId, name, roomName) : null,
                ),
                _buildActionButton(
                  icon: Icons.calendar_today,
                  label: "Schedule",
                  color: Colors.purple,
                  onPressed: () => _showScheduleDialog(context, counselorId, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
    );
  }

  Future<void> _initiateCall(String counselorId, String counselorName, String roomName) async {
    try {
      // Check wallet balance
      final balance = await _walletService.getBalance();
      const callCost = 100.0; // ₹100 per call
      
      if (balance < callCost) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Insufficient balance. Please recharge your wallet.")),
        );
        return;
      }
      
      // Deduct from wallet
      await _walletService.deductMoney(callCost, "Call with $counselorName");
      
      // Create a call record
      final userId = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('calls').add({
        'userId': userId,
        'counselorId': counselorId,
        'startTime': FieldValue.serverTimestamp(),
        'isAudioOnly': isAudioOnly,
        'status': 'ongoing',
      });
      
      // Navigate to call screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            roomCode: roomName,
            userName: "User", // Replace with dynamic user name
            isAudioOnly: isAudioOnly,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _showScheduleDialog(BuildContext context, String counselorId, String counselorName) async {
    DateTime selectedDate = DateTime.now().add(Duration(days: 1));
    String selectedTime = '10:00 AM';
    int selectedDuration = 30; // minutes
    
    final availableTimes = [
      '9:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
      '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM', '5:00 PM'
    ];
    
    final availableDurations = [30, 45, 60]; // minutes
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Schedule Session with $counselorName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                            Icon(Icons.calendar_month),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text('Select Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedTime,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: availableTimes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedTime = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Text('Session Duration:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedDuration,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: availableDurations
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d minutes')))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedDuration = value);
                        }
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    Text(
                      'Note: ₹${selectedDuration * 2} will be charged for this session',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _scheduleSession(
                    counselorId: counselorId, 
                    counselorName: counselorName,
                    selectedDate: selectedDate,
                    selectedTime: selectedTime,
                    duration: selectedDuration,
                  ),
                  child: Text('Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _scheduleSession({
    required String counselorId,
    required String counselorName,
    required DateTime selectedDate,
    required String selectedTime,
    required int duration,
  }) async {
    try {
      // Parse time
      final timeParts = selectedTime.split(':');
      final hour = int.parse(timeParts[0]);
      int minute = 0;
      
      if (timeParts[1].contains('PM') && hour < 12) {
        // Convert to 24-hour format
        final adjustedHour = hour + 12;
        final minutePart = timeParts[1].split(' ')[0];
        minute = int.parse(minutePart);
      } else {
        final minutePart = timeParts[1].split(' ')[0];
        minute = int.parse(minutePart);
      }
      
      // Create datetime for the session
      final sessionDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        hour,
        minute,
      );
      
      // Calculate cost
      final cost = duration * 2.0; // ₹2 per minute
      
      // Check wallet balance
      final balance = await _walletService.getBalance();
      if (balance < cost) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Insufficient balance. Please recharge your wallet.")),
        );
        return;
      }
      
      // Deduct from wallet
      await _walletService.deductMoney(cost, "Session scheduled with $counselorName");
      
      // Create session
      final userId = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('sessions').add({
        'userId': userId,
        'counselorId': counselorId,
        'scheduledAt': Timestamp.fromDate(sessionDateTime),
        'duration': duration,
        'status': 'scheduled',
        'cost': cost,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Session scheduled successfully!")),
      );
    } catch (e) {
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
