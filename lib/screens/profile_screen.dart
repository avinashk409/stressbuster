import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  const ProfileScreen({super.key, FirebaseFirestore? firestore, FirebaseAuth? auth})
      : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  String _gender = 'Male';
  bool _isLoading = false;
  double _walletBalance = 0.0;
  String? _email;

  User? get user => widget.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  /// Loads existing profile from Firestore and populates fields
  Future<void> _loadUserProfile() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    final snapshot = await widget.firestore
        .collection('users')
        .doc(user!.uid)
        .get();

    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>?;

      _nameController.text = data?['name'] ?? '';
      _ageController.text = data?['age']?.toString() ?? '';
      _gender = data?['gender'] ?? 'Male';
      _walletBalance = (data?['walletBalance'] ?? 0.0).toDouble();
      _email = data?['email'] ?? user?.email;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Saves updated profile to Firestore
  Future<void> _saveUserProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (user == null) return;

    final data = {
      'name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 0,
      'gender': _gender,
      'email': _email ?? user!.email,
      'uid': user!.uid,
      'walletBalance': _walletBalance,
    };

    setState(() => _isLoading = true);

    await widget.firestore
        .collection('users')
        .doc(user!.uid)
        .set(data);

    if (mounted) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Profile updated successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet Balance Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Wallet Balance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${_walletBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Email Display
                    if (_email != null) ...[
                      Text(
                        'Email',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _email!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                    ],

                    /// Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 10),

                    /// Age
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                      validator: (value) {
                        final age = int.tryParse(value ?? '');
                        if (value == null || value.isEmpty) return 'Please enter your age';
                        if (age == null || age <= 0 || age > 120) return 'Enter a valid age';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    /// Gender Dropdown
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _gender = value);
                      },
                    ),
                    const SizedBox(height: 30),

                    /// Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("Save Profile"),
                        onPressed: _saveUserProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
