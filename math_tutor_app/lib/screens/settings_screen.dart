import 'package:flutter/material.dart';
import '../constants/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'General',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Enable push notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              activeColor: AppColors.primary,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            subtitle: 'Use dark theme',
            trailing: Switch(
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
              },
              activeColor: AppColors.primary,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: _selectedLanguage,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
            onTap: () {
              _showLanguageDialog();
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.info,
            title: 'Version',
            subtitle: '1.0.0',
            trailing: const SizedBox(),
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
            onTap: () {
              // TODO: Open privacy policy
            },
          ),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'View terms and conditions',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
            onTap: () {
              // TODO: Open terms of service
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Support',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.help,
            title: 'Help & FAQ',
            subtitle: 'Get help and answers',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
            onTap: () {
              // TODO: Open help
            },
          ),
          _buildSettingsTile(
            icon: Icons.feedback,
            title: 'Send Feedback',
            subtitle: 'Help us improve',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
            onTap: () {
              // TODO: Open feedback form
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
              onPressed: () {
                _showLogoutDialog();
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Clear All Data',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
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
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Select Language', style: TextStyle(color: AppColors.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English'),
            _buildLanguageOption('Spanish'),
            _buildLanguageOption('French'),
            _buildLanguageOption('German'),
            _buildLanguageOption('Chinese'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    return RadioListTile<String>(
      title: Text(language, style: const TextStyle(color: AppColors.textWhite)),
      value: language,
      groupValue: _selectedLanguage,
      activeColor: AppColors.primary,
      onChanged: (value) {
        setState(() {
          _selectedLanguage = value!;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Clear All Data?', style: TextStyle(color: AppColors.textWhite)),
        content: const Text(
          'This will delete all your history and preferences. This action cannot be undone.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () {
              // TODO: Clear all data
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data cleared'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}