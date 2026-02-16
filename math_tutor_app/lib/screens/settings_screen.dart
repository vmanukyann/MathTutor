import 'package:flutter/material.dart';
import 'dart:io';
import '../constants/colors.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import 'login_screen.dart';
import 'package:camera/camera.dart';

class SettingsScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const SettingsScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabaseService = SupabaseService();
  final _localStorage = LocalStorageService();
  
  String _userName = '';
  String _userEmail = '';
  bool _isLoading = true;
  bool _isEditingProfile = false;
  String? _profileImagePath; // Local profile image path
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _supabaseService.getUserProfile();
      
      // Load profile image from local storage if exists
      final prefs = await _localStorage.getUserData();
      final savedImagePath = prefs?['profile_image_path'] as String?;
      
      setState(() {
        _userName = profile?['full_name'] ?? 'Student';
        _userEmail = profile?['email'] ?? '';
        _nameController.text = _userName;
        _emailController.text = _userEmail;
        _profileImagePath = savedImagePath;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _userName = 'Student';
        _isLoading = false;
      });
    }
  }

  Future<void> _changeProfilePicture() async {
    // Show a message that this feature requires the image_picker package
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Profile Picture', style: TextStyle(color: AppColors.textWhite)),
        content: const Text(
          'Failed to upload media',
          style: TextStyle(color: AppColors.textGrey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      // Update profile in Supabase
      await _supabaseService.updateProfile(
        fullName: _nameController.text.trim(),
      );
      
      setState(() {
        _userName = _nameController.text.trim();
        _isEditingProfile = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile Updated!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isEditingProfile)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditingProfile = false;
                  _nameController.text = _userName;
                  _emailController.text = _userEmail;
                });
              },
              child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Profile Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Avatar with change button
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                        image: _profileImagePath != null && File(_profileImagePath!).existsSync()
                            ? DecorationImage(
                                image: FileImage(File(_profileImagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profileImagePath == null
                          ? Center(
                              child: Text(
                                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _changeProfilePicture,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardBackground, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Name field (editable)
                if (_isEditingProfile)
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textWhite),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: AppColors.textGrey.withOpacity(0.7)),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  )
                else
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                    textAlign: TextAlign.center,
                  ),
                
                const SizedBox(height: 8),
                
                // Email (read-only display)
                Text(
                  _userEmail,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGrey.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                // Edit/Save button
                if (_isEditingProfile)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditingProfile = true;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                    label: const Text(
                      'Edit Profile',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Menu Items
          _buildMenuTile(
            icon: Icons.person_outline,
            title: 'Profile Settings',
            subtitle: 'Manage your account',
            onTap: () {
              setState(() {
                _isEditingProfile = true;
              });
            },
          ),
          
          _buildMenuTile(
            icon: Icons.help_outline,
            title: 'FAQ',
            subtitle: 'Frequently asked questions',
            onTap: () {
              _showFAQDialog();
            },
          ),
          
          _buildMenuTile(
            icon: Icons.feedback_outlined,
            title: 'Send Feedback',
            subtitle: 'Help us improve',
            onTap: () {
              _showFeedbackDialog();
            },
          ),
          
          _buildMenuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () {
              _showPrivacyPolicy();
            },
          ),
          
          _buildMenuTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Terms and conditions',
            onTap: () {
              _showTermsOfService();
            },
          ),
          
          _buildMenuTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0',
            onTap: null,
          ),
          
          const SizedBox(height: 32),
          
          // Logout button
          Center(
            child: TextButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textGrey.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        trailing: onTap != null 
            ? const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey)
            : null,
        onTap: onTap,
      ),
    );
  }

  void _showFAQDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('FAQ', style: TextStyle(color: AppColors.textWhite)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFAQItem(
                'How do I scan a problem?',
                'Tap the scan button on the home screen, align your math problem within the frame, and take a picture.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'Can I edit my solutions?',
                'Yes! Tap on any problem in your history to view and review the solution steps.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'Is my data secure?',
                'Absolutely. All your data is encrypted and stored securely. We never share your information.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'How do I delete my account?',
                'Contact support at support@mathtutor.com to request account deletion.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: TextStyle(
            color: AppColors.textGrey.withOpacity(0.9),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Send Feedback', style: TextStyle(color: AppColors.textWhite)),
        content: TextField(
          controller: feedbackController,
          maxLines: 5,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'Tell us what you think...',
            hintStyle: TextStyle(color: AppColors.textGrey.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement feedback submission
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Send', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Privacy Policy', style: TextStyle(color: AppColors.textWhite)),
        content: SingleChildScrollView(
          child: Text(
            'MathTutor Privacy Policy\n\n'
            'Last updated: February 2026\n\n'
            '1. Information We Collect\n'
            'We collect your email address, name, and problem-solving history to provide our services.\n\n'
            '2. How We Use Your Information\n'
            'Your data is used solely to provide educational services and track your progress.\n\n'
            '3. Data Security\n'
            'We use industry-standard encryption to protect your data.\n\n'
            '4. Data Sharing\n'
            'We do not share your personal information with third parties.\n\n'
            '5. Your Rights\n'
            'You can request to view, edit, or delete your data at any time.\n\n'
            'For questions, contact: privacy@mathtutor.com',
            style: TextStyle(color: AppColors.textGrey.withOpacity(0.9), fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Terms of Service', style: TextStyle(color: AppColors.textWhite)),
        content: SingleChildScrollView(
          child: Text(
            'MathTutor Terms of Service\n\n'
            'Last updated: February 2026\n\n'
            '1. Acceptance of Terms\n'
            'By using MathTutor, you agree to these terms.\n\n'
            '2. User Accounts\n'
            'You must provide accurate information and keep your account secure.\n\n'
            '3. Acceptable Use\n'
            'Use MathTutor for educational purposes only. Do not attempt to cheat or misuse the service.\n\n'
            '4. Content\n'
            'Solutions provided are for learning purposes. We strive for accuracy but are not liable for errors.\n\n'
            '5. Account Termination\n'
            'We reserve the right to terminate accounts that violate these terms.\n\n'
            '6. Changes to Terms\n'
            'We may update these terms. Continued use means you accept the changes.\n\n'
            'For questions, contact: support@mathtutor.com',
            style: TextStyle(color: AppColors.textGrey.withOpacity(0.9), fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Sign Out?', style: TextStyle(color: AppColors.textWhite)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Sign out from Supabase
      await _supabaseService.signOut();
      
      // Clear local user data (but keep history)
      await _localStorage.clearUserData();
      
      if (mounted) {
        // Navigate back to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(cameras: widget.cameras),
          ),
          (route) => false,
        );
      }
    }
  }
}