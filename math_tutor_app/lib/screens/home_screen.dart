import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';
import 'scan_screen.dart';

// Main home screen widget - shows personalized landing page
class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _supabaseService = SupabaseService();
  
  // User data
  String _userName = '';
  List<Map<String, dynamic>> _topSkills = [];
  bool _isLoading = true;
  
  // Controllers for animations
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  @override
  bool get wantKeepAlive => false; // Don't keep state alive, always refresh

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    
    // Load user data
    _loadUserData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // Add this method to refresh data when returning to screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // DEBUG: Check auth state
      final user = _supabaseService.currentUser;
      final session = _supabaseService.currentSession;
      
      print('=== HOME SCREEN DEBUG ===');
      print('uid=${user?.id} session=${session != null}');
      
      // Get user profile - force fresh data
      final profile = await _supabaseService.getUserProfile();
      print('profile=$profile');
      
      // Get top skills
      final skills = await _supabaseService.getTopSkills(limit: 2);
      
      // Try to get name from auth metadata as fallback
      final metaName = user?.userMetadata?['full_name'] as String?;
      print('metaName=$metaName');
      
      if (mounted) {
        setState(() {
          _userName = (profile?['full_name'] as String?) ?? metaName ?? 'Student';
          _topSkills = skills;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _userName = 'Student';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      body: Stack(
        children: [
          // Dark gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF000000),
                  Color(0xFF0A0A0A),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),
          
          // Floating math symbols
          ...List.generate(5, (index) {
            return AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Positioned(
                  top: 100 + (index * 120.0) + _floatAnimation.value,
                  left: index.isEven ? 30 : null,
                  right: index.isOdd ? 30 : null,
                  child: Opacity(
                    opacity: 0.05,
                    child: Text(
                      ['∑', '∫', 'π', '√', '∞'][index],
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          SafeArea(
            child: Column(
              children: [
                // Top header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calculate, 
                          color: AppColors.primary, size: 24),
                      ),
                      
                      // App name
                      const Text(
                        'MathTutor',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      
                      // Profile/Settings button
                      IconButton(
                        icon: const Icon(Icons.person, 
                          color: AppColors.textGrey),
                        onPressed: () {
                          // Navigate to settings (handled by bottom nav)
                        },
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),

                // Main content area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Personalized greeting
                      _isLoading
                          ? const SizedBox(height: 40)
                          : Column(
                              children: [
                                Text(
                                  'Hi, $_userName',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Skills progress (if available)
                                if (_topSkills.isNotEmpty) ...[
                                  _buildSkillsProgress(),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            ),
                      
                      // Main headline
                      const Text(
                        'Ready to learn?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Subtitle
                      Text(
                        'Scan any problem to get started',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                      ),
                      
                      const SizedBox(height: 60),

                      // Big circular scan button
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => 
                                  ScanScreen(cameras: widget.cameras),
                              ),
                            );
                          },
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 40,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, 
                                  size: 56, color: Colors.white),
                                SizedBox(height: 12),
                                Text(
                                  'Scan',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 50),

                      // Secondary action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _QuickActionButton(
                            icon: Icons.keyboard_outlined,
                            label: 'Type',
                            onTap: () {
                              // TODO: open keyboard input screen
                            },
                          ),
                          const SizedBox(width: 20),
                          _QuickActionButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Upload',
                            onTap: () {
                              // TODO: open image picker
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the skills progress widget
  Widget _buildSkillsProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currently working on:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGrey.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_topSkills.length, (index) {
            final skill = _topSkills[index];
            final percentage = skill['percentage'] as int;
            final skillName = skill['skill_category'] as String;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Percentage badge
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$percentage%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Skill name
                  Expanded(
                    child: Text(
                      skillName,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Quick action button widget
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}