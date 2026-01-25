import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../constants/colors.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Container(
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
              );
            },
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
                // Modern header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calculate, color: AppColors.primary, size: 24),
                      ),
                      const Text(
                        'MathTutor',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history, color: AppColors.textGrey),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Main content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Title
                      const Text(
                        'Solve any problem',
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
                      
                      Text(
                        'Scan, solve, and understand math instantly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                      ),
                      
                      const SizedBox(height: 60),

                      // Scan button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScanScreen(cameras: widget.cameras),
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
                              Icon(Icons.camera_alt_rounded, size: 56, color: Colors.white),
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

                      const SizedBox(height: 50),

                      // Quick action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _QuickActionButton(
                            icon: Icons.keyboard_outlined,
                            label: 'Type',
                            onTap: () {},
                          ),
                          const SizedBox(width: 20),
                          _QuickActionButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Upload',
                            onTap: () {},
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
}

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