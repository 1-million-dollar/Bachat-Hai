import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  
 runApp(AuthApp());

}

class AuthApp extends StatelessWidget {
  const AuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bachat Ha!',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _regNoController = TextEditingController();

  String _verificationId = '';
  bool _isLoading = false;
  String _message = '';
  User? _user;
  bool _showProfileForm = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    _auth.authStateChanges().listen((User? user) async {
      if (mounted) {
        setState(() => _user = user);
        
        if (user != null) {
          await _loadUserProfile();
        }
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final doc = await _firestore.collection('user_profiles').doc(_user!.uid).get();
      if (mounted) {
        setState(() {
          _userProfile = doc.data();
          if (_userProfile == null) {
            _showProfileForm = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Failed to load profile: ${e.toString()}');
      }
    }
  }

  Future<void> _verifyPhoneNumber() async {
    if (_phoneController.text.isEmpty) {
      _showError('Please enter phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Sending verification code...';
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: (verificationId, _) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _message = 'Code sent! Check your phone';
              _isLoading = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      _showError('Failed to verify: ${e.toString()}');
    }
  }

  Future<void> _onVerificationCompleted(PhoneAuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
      if (mounted) {
        setState(() => _message = 'Login successful!');
      }
    } catch (e) {
      _showError('Auto-verification failed: ${e.toString()}');
    }
  }

  void _onVerificationFailed(FirebaseAuthException e) {
    _showError('Verification failed: ${e.message}');
  }

  Future<void> _signInWithSmsCode() async {
    if (_smsController.text.isEmpty) {
      _showError('Please enter verification code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _smsController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
    } catch (e) {
      _showError('Invalid code. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitProfile() async {
    if (_nameController.text.isEmpty || 
        _addressController.text.isEmpty || 
        _regNoController.text.isEmpty) {
      _showError('Please fill all profile fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('user_profiles').doc(_user!.uid).set({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'regNo': _regNoController.text.trim(),
        'phone': _user!.phoneNumber,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _loadUserProfile();
      
      _nameController.clear();
      _addressController.clear();
      _regNoController.clear();
      
      _showSuccess('Profile saved successfully!');
      setState(() => _showProfileForm = false);
    } catch (e) {
      _showError('Failed to save profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      _smsController.clear();
      _showSuccess('Signed out successfully');
      if (mounted) {
        setState(() {
          _showProfileForm = false;
          _userProfile = null;
        });
      }
    } catch (e) {
      _showError('Sign out failed: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _message = message;
        _isLoading = false;
      });
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      setState(() {
        _message = message;
        _isLoading = false;
      });
    }
  }

  void _navigateToThankYouPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Thank You')),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 100),
                SizedBox(height: 20),
                Text(
                  'Payment Successful!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('Thank you for your payment.'),
                SizedBox(height: 20),
                Text('Your transaction has been completed successfully.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bachat Ha!'),
        actions: _user != null ? [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              if (_userProfile != null) {
                setState(() => _showProfileForm = true);
              }
            },
          )
        ] : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _user == null 
            ? _buildAuthForm() 
            : _showProfileForm 
                ? _buildProfileForm() 
                : _buildProfilePage(),
      ),
    );
  }

  Widget _buildAuthForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Sign In', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+919876543210',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          if (_verificationId.isEmpty)
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyPhoneNumber,
              child: const Text('Send OTP'),
            )
          else ...[
            TextField(
              controller: _smsController,
              decoration: const InputDecoration(
                labelText: 'Verification Code',
                prefixIcon: Icon(Icons.sms),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _signInWithSmsCode,
              child: const Text('Verify & Sign In'),
            ),
          ],
          const SizedBox(height: 20),
          if (_isLoading) const CircularProgressIndicator(),
          if (_message.isNotEmpty)
            Text(
              _message,
              style: TextStyle(
                color: _message.contains('success') ? Colors.green : Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            _userProfile == null ? 'Complete Your Profile' : 'Update Profile',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              border: const OutlineInputBorder(),
              hintText: _userProfile?['name'],
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Address',
              border: const OutlineInputBorder(),
              hintText: _userProfile?['address'],
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _regNoController,
            decoration: InputDecoration(
              labelText: 'Registration Number',
              border: const OutlineInputBorder(),
              hintText: _userProfile?['regNo'],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitProfile,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Profile'),
          ),
          const SizedBox(height: 15),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _showProfileForm = false;
                if (_userProfile == null) {
                  _signOut();
                }
              });
            },
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 10),
          Text(
            _message,
            style: TextStyle(
              color: _message.contains('success') ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    if (_userProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No profile data available'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _showProfileForm = true),
              child: const Text('Create Profile'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildProfileItem('Name', _userProfile!['name']),
          _buildProfileItem('Phone', _userProfile!['phone']),
          _buildProfileItem('Address', _userProfile!['address']),
          _buildProfileItem('Registration No.', _userProfile!['regNo']),
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton(
              onPressed: _navigateToThankYouPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('Pay Now', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: ElevatedButton(
              onPressed: () => setState(() => _showProfileForm = true),
              child: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: ElevatedButton(
              onPressed: _signOut,
              child: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18),
          ),
          const Divider(),
        ],
      ),
    );
  }
}