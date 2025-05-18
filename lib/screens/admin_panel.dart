import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String _message = '';
  late TabController _tabController;
  String _searchQuery = '';
  
  // Pagination variables
  static const int _usersPerPage = 10;
  DocumentSnapshot? _lastUserDocument;
  bool _hasMoreUsers = true;
  bool _isLoadingMore = false;
  List<DocumentSnapshot> _usersList = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialUsers();
    _ensureAdminExists();
  }
  
  @override
  void dispose() {
    _userIdController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUsers() async {
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      // First check if the current user is an admin
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
          
      if (!userDoc.exists || userDoc.data()?['isAdmin'] != true) {
        throw Exception('Access denied: User is not an admin');
      }
      
      // Create a query with proper error handling
      final usersQuery = FirebaseFirestore.instance
          .collection('users')
          .where('isCounselor', isEqualTo: false)
          .limit(_usersPerPage);
      
      final snapshot = await usersQuery.get();
      
      if (snapshot.docs.isEmpty) {
        print("No users found in the Firestore collection");
      } else {
        print("Found ${snapshot.docs.length} users in Firestore");
      }
      
      setState(() {
        _usersList = snapshot.docs;
        if (snapshot.docs.isNotEmpty) {
          _lastUserDocument = snapshot.docs.last;
        }
        _hasMoreUsers = snapshot.docs.length == _usersPerPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      print("Error loading users: $e");
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e')),
      );
    }
  }

  Future<void> _loadMoreUsers() async {
    if (!_hasMoreUsers || _isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final usersQuery = FirebaseFirestore.instance
          .collection('users')
          .where('isCounselor', isEqualTo: false)
          .startAfterDocument(_lastUserDocument!)
          .limit(_usersPerPage);
      
      final snapshot = await usersQuery.get();
      
      setState(() {
        _usersList.addAll(snapshot.docs);
        if (snapshot.docs.isNotEmpty) {
          _lastUserDocument = snapshot.docs.last;
        }
        _hasMoreUsers = snapshot.docs.length == _usersPerPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      print("Error loading more users: $e");
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more users: $e')),
      );
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      _loadInitialUsers();
      return;
    }
    
    setState(() {
      _isLoadingMore = true;
      _usersList = [];
    });
    
    try {
      // Search by name (case insensitive search not directly supported in Firestore)
      final nameSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .where('isCounselor', isEqualTo: false)
          .get();
          
      // Search by email
      final emailSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .where('isCounselor', isEqualTo: false)
          .get();
      
      // Combine results and remove duplicates
      final Map<String, DocumentSnapshot> uniqueResults = {};
      
      for (var doc in nameSnapshot.docs) {
        uniqueResults[doc.id] = doc;
      }
      
      for (var doc in emailSnapshot.docs) {
        uniqueResults[doc.id] = doc;
      }
      
      setState(() {
        _usersList = uniqueResults.values.toList();
        _hasMoreUsers = false; // Don't enable pagination for search results
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // Check if the current user is an admin - if not, show access denied
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Panel')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final isAdmin = userData?['isAdmin'] == true;
        
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Denied'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await authService.signOut();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                )
              ],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 64, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text('You do not have permission to access the admin panel.'),
                ],
              ),
            ),
          );
        }
        
        // User is an admin, show admin panel
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Panel'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await authService.signOut();
                  Navigator.pushReplacementNamed(context, '/');
                },
              )
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Users'),
                Tab(text: 'Counselors'),
                Tab(text: 'Requests'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildUsersTab(),
              _buildCounselorsTab(),
              _buildRequestsTab(),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildUsersTab() {
    return Column(
      children: [
        // Search field with improved design
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by email or name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty 
                      ? null 
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                            _loadInitialUsers();
                          },
                        ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final query = _searchController.text.trim().toLowerCase();
                  setState(() {
                    _searchQuery = query;
                  });
                  _searchUsers(query);
                },
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        
        // Users count and refresh button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${_usersList.length} ${_searchQuery.isEmpty ? 'users' : 'results'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadInitialUsers,
                tooltip: 'Refresh list',
              ),
            ],
          ),
        ),
        
        // Users list with pagination
        Expanded(
          child: _isLoadingMore && _usersList.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _usersList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No users found'
                                : 'No users match "$_searchQuery"'
                          ),
                          const SizedBox(height: 24),
                          if (_searchQuery.isNotEmpty)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear Search'),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _loadInitialUsers();
                              },
                            ),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
                            _hasMoreUsers && !_isLoadingMore) {
                          _loadMoreUsers();
                          return true;
                        }
                        return false;
                      },
                      child: ListView.builder(
                        itemCount: _usersList.length + (_hasMoreUsers ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _usersList.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          final userData = _usersList[index].data() as Map<String, dynamic>;
                          final userId = _usersList[index].id;
                          
                          final email = userData['email'] ?? 'No email';
                          final name = userData['name'] ?? email.toString().split('@')[0];
                          final photoURL = userData['photoURL'] ?? '';
                          final walletBalance = userData['walletBalance'] ?? 0.0;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Hero(
                                      tag: 'user-avatar-$userId',
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.blue.shade100,
                                        backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                                        child: photoURL.isEmpty 
                                          ? Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                              style: const TextStyle(
                                                fontSize: 24, 
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ) 
                                          : null,
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(email),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.account_balance_wallet, size: 16, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Text(
                                              '₹${walletBalance.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: _isLoading && _userIdController.text == userId
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : null,
                                  ),
                                  const Divider(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Edit User'),
                                            onPressed: () => _showEditUserDialog(userId, userData),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.person_add),
                                            label: const Text('Make Counselor'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => _assignCounselorRole(userId, userData),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
  
  void _showEditUserDialog(String userId, Map<String, dynamic> userData) {
    final nameController = TextEditingController(text: userData['name'] ?? '');
    final walletController = TextEditingController(
      text: (userData['walletBalance'] ?? 0.0).toString()
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: walletController,
              decoration: const InputDecoration(
                labelText: 'Wallet Balance (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final newName = nameController.text.trim();
                final newWalletBalance = double.tryParse(walletController.text) ?? 0.0;
                
                await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({
                    'name': newName,
                    'walletBalance': newWalletBalance,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User updated successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCounselorsTab() {
    return Column(
      children: [
        // Search field for counselors
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search counselors',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        
        Expanded(
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .get(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (adminSnapshot.hasError) {
                return Center(child: Text('Error: ${adminSnapshot.error}'));
              }
              
              final adminData = adminSnapshot.data?.data() as Map<String, dynamic>?;
              final isAdmin = adminData?['isAdmin'] == true;
              
              if (!isAdmin) {
                return const Center(child: Text('Access denied: User is not an admin'));
              }
              
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('isCounselor', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No counselors found'));
                  }
                  
                  var counselors = snapshot.data!.docs;
                  
                  // Filter counselors based on search query
                  if (_searchQuery.isNotEmpty) {
                    counselors = counselors.where((doc) {
                      final counselorData = doc.data() as Map<String, dynamic>;
                      final email = (counselorData['email'] ?? '').toLowerCase();
                      final name = (counselorData['name'] ?? '').toLowerCase();
                      final specialty = (counselorData['specialty'] ?? '').toLowerCase();
                      
                      return email.contains(_searchQuery) || 
                            name.contains(_searchQuery) ||
                            specialty.contains(_searchQuery);
                    }).toList();
                  }
                  
                  return ListView.builder(
                    itemCount: counselors.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final counselorData = counselors[index].data() as Map<String, dynamic>;
                      final counselorId = counselors[index].id;
                      
                      final email = counselorData['email'] ?? 'No email';
                      final name = counselorData['name'] ?? email.toString().split('@')[0];
                      final specialty = counselorData['specialty'] ?? 'General Counseling';
                      final isAvailable = counselorData['isAvailable'] ?? false;
                      final photoURL = counselorData['photoURL'] ?? counselorData['image'] ?? '';
                      final earnings = counselorData['earnings'] ?? 0.0;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                                    child: photoURL.isEmpty ? const Icon(Icons.person, size: 30) : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isAvailable ? Colors.green : Colors.red,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                isAvailable ? 'Available' : 'Unavailable',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(email),
                                        const SizedBox(height: 8),
                                        Text('Specialty: $specialty'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Earnings:',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      Text(
                                        '₹${earnings.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Edit'),
                                        onPressed: () {
                                          _showEditCounselorDialog(counselorId, counselorData);
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.remove_circle),
                                        label: const Text('Remove Role'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _removeCounselorRole(counselorId),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
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
    );
  }
  
  void _showEditCounselorDialog(String counselorId, Map<String, dynamic> counselorData) {
    final nameController = TextEditingController(text: counselorData['name'] ?? '');
    final specialtyController = TextEditingController(text: counselorData['specialty'] ?? 'General Counseling');
    final rateController = TextEditingController(text: (counselorData['sessionRate'] ?? 500).toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Counselor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: specialtyController,
                decoration: const InputDecoration(
                  labelText: 'Specialty',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                  labelText: 'Session Rate (₹)',
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
              try {
                final name = nameController.text.trim();
                final specialty = specialtyController.text.trim();
                final rate = double.tryParse(rateController.text) ?? 500;
                
                await FirebaseFirestore.instance
                  .collection('users')
                  .doc(counselorId)
                  .update({
                    'name': name,
                    'specialty': specialty,
                    'sessionRate': rate,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Counselor updated successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No withdrawal requests found'),
              ],
            ),
          );
        }
        
        final requests = snapshot.data!.docs;
        
        return ListView.builder(
          itemCount: requests.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final requestId = requests[index].id;
            
            final counselorId = requestData['counselorId'] ?? '';
            final amount = requestData['amount'] ?? 0.0;
            final status = requestData['status'] ?? 'pending';
            final timestamp = requestData['created_at'] as Timestamp?;
            final bankDetails = requestData['bankDetails'] as Map<String, dynamic>?;
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(counselorId)
                  .get(),
              builder: (context, userSnapshot) {
                String counselorName = 'Unknown';
                String counselorEmail = '';
                
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  counselorName = userData['name'] ?? 'Counselor';
                  counselorEmail = userData['email'] ?? '';
                }
                
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
                    statusIcon = Icons.pending;
                }
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    counselorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (counselorEmail.isNotEmpty)
                                    Text(counselorEmail),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Icon(statusIcon, color: statusColor, size: 18),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Amount: ₹${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (timestamp != null)
                          Text(
                            'Requested on: ${_formatDate(timestamp.toDate())}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        
                        if (bankDetails != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Bank Details:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Account Number: ${bankDetails['accountNumber'] ?? 'Not provided'}'),
                          Text('IFSC Code: ${bankDetails['ifscCode'] ?? 'Not provided'}'),
                          Text('Account Holder: ${bankDetails['accountName'] ?? 'Not provided'}'),
                        ],
                        
                        const SizedBox(height: 16),
                        if (status == 'pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => _updateRequestStatus(requestId, 'rejected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => _updateRequestStatus(requestId, 'completed'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  Future<void> _assignCounselorRole(String userId, Map<String, dynamic> userData) async {
    // Show dialog to collect counselor information
    final specialtyController = TextEditingController(text: 'General Counseling');
    final rateController = TextEditingController(text: '500');
    final selectedSpecialty = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Counselor Role'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please provide the counselor details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: specialtyController,
                decoration: const InputDecoration(
                  labelText: 'Specialty',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Depression, Anxiety, Relationship',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                  labelText: 'Session Rate (₹)',
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
            onPressed: () {
              final specialty = specialtyController.text.trim();
              final rate = double.tryParse(rateController.text) ?? 500.0;
              
              Navigator.pop(context, {
                'specialty': specialty,
                'sessionRate': rate,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
            ),
            child: const Text('Assign Role'),
          ),
        ],
      ),
    );

    if (selectedSpecialty == null) return;
    
    // Set the user ID for loading indicator
    setState(() {
      _isLoading = true;
      _userIdController.text = userId;
    });
    
    try {
      // Update the user document with counselor fields
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
            'isCounselor': true,
            'role': 'counselor',
            'specialty': selectedSpecialty['specialty'],
            'rating': 4.5,
            'isAvailable': true,
            'sessionRate': selectedSpecialty['sessionRate'],
            'earnings': 0.0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Reload users list after assigning role
      _loadInitialUsers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User has been assigned the counselor role'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _userIdController.text = '';
      });
    }
  }
  
  Future<void> _removeCounselorRole(String userId) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Counselor Role'),
          content: const Text(
            'Are you sure you want to remove the counselor role from this user? They will no longer be able to provide counseling services.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove Role'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
            'isCounselor': false,
            'role': 'user',
            'isAvailable': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Counselor role has been removed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .doc(requestId)
          .update({
            'status': status,
            'processed_at': FieldValue.serverTimestamp(),
            'processed_by': FirebaseAuth.instance.currentUser?.uid,
          });
      
      final message = status == 'completed' 
          ? 'Payment request approved'
          : 'Payment request rejected';
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: status == 'completed' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureAdminExists() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Check if the current user is an admin in Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!userDoc.exists) {
        // Create a new user document with admin privileges
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
              'email': currentUser.email,
              'name': currentUser.displayName ?? 'Admin User',
              'isAdmin': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
            
        print('Created new admin user in Firestore');
      } else {
        // Update the existing user to be an admin
        if (userDoc.data()?['isAdmin'] != true) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
                'isAdmin': true,
              });
              
          print('Updated user to admin status in Firestore');
        }
      }
    } catch (e) {
      print('Error ensuring admin exists: $e');
    }
  }
} 