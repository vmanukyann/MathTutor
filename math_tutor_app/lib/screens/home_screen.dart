import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
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

class _HomeScreenState extends State<HomeScreen> {
  final _supabaseService = SupabaseService();

  // User data
  String _userName = '';
  List<Map<String, dynamic>> _topSkills = [];
  bool _isLoading = true;

  // Weekly chart data
  List<int> _weekCounts = List.filled(7, 0);
  bool _loadingWeek = true;

  // Stats
  int _totalProblems = 0;
  int _problemsThisWeek = 0;

  DateTime? _parseDateTime(dynamic raw) {
    if (raw is DateTime) return raw.toLocal();
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadWeeklyCounts();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
    _loadWeeklyCounts();
    _loadStats();
  }

  /// ✅ Time-based + slightly random greeting
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;

    String timePhrase;
    if (hour >= 5 && hour < 12) {
      timePhrase = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      timePhrase = 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      timePhrase = 'Good Evening';
    } else if (hour >= 21 && hour < 24) {
      timePhrase = "It's Late Night";
    } else {
      timePhrase = 'Burning the Midnight Oil';
    }

    // Optional extra line (random)
    final extras = <String>[
      '',
      'Ready to level up?',
      "Let's crush some math.",
      'Time to get sharper.',
      "Let's make progress.",
    ];

    final extra = extras[Random().nextInt(extras.length)];

    // If no extra, keep it one-line clean
    if (extra.isEmpty) return '$timePhrase, $_userName';

    // If extra exists, show it on a 2nd line
    return '$timePhrase, $_userName\n$extra';
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabaseService.currentUser;
      final profile = await _supabaseService.getUserProfile();
      final skills = await _supabaseService.getTopSkills(limit: 2);
      final metaName = user?.userMetadata?['full_name'] as String?;

      if (mounted) {
        setState(() {
          _userName =
              (profile?['full_name'] as String?) ?? metaName ?? 'Student';
          _topSkills = skills;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'Student';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWeeklyCounts() async {
    if (!_supabaseService.isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _weekCounts = List.filled(7, 0);
        _loadingWeek = false;
      });
      return;
    }

    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    try {
      final history = await _supabaseService.getProblemHistory(
        startDate: startOfWeek,
      );

      final counts = List<int>.filled(7, 0);
      for (final item in history) {
        final solvedAt = _parseDateTime(item['solved_at']);
        if (solvedAt == null) continue;
        final index = solvedAt.weekday - 1;
        if (index >= 0 && index < 7) counts[index]++;
      }

      if (!mounted) return;
      setState(() {
        _weekCounts = counts;
        _loadingWeek = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weekCounts = List.filled(7, 0);
        _loadingWeek = false;
      });
    }
  }

  Future<void> _loadStats() async {
    if (!_supabaseService.isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _totalProblems = 0;
        _problemsThisWeek = 0;
      });
      return;
    }

    try {
      final stats = await _supabaseService.getUserStats();
      if (mounted) {
        setState(() {
          _totalProblems = stats['total_problems'] ?? 0;
          _problemsThisWeek = stats['problems_this_week'] ?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _totalProblems = 0;
          _problemsThisWeek = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUserData();
            await _loadWeeklyCounts();
            await _loadStats();
          },
          color: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with greeting
                  _buildHeader(),

                  const SizedBox(height: 32),

                  // Stats cards
                  _buildStatsRow(),

                  const SizedBox(height: 24),

                  // Weekly activity chart
                  _buildWeeklyActivityCard(),

                  const SizedBox(height: 24),

                  // Skills progress (if available)
                  if (_topSkills.isNotEmpty) ...[
                    _buildSkillsCard(),
                    const SizedBox(height: 24),
                  ],

                  // Main scan button
                  _buildScanButton(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo/Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calculate,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MathTutor',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            // Settings icon
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: () {
                // Navigate to settings
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ✅ Greeting
        if (!_isLoading) ...[
          Text(
            _getTimeBasedGreeting(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s solve some problems today',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Solved',
            _totalProblems.toString(),
            Icons.check_circle_outline,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'This Week',
            _problemsThisWeek.toString(),
            Icons.calendar_today,
            const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_weekCounts.reduce((a, b) => a + b)} problems',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(height: 200, child: _buildWeeklyChart()),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (_loadingWeek) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final peakCount = _weekCounts.reduce(max);
    final maxY = max(1, peakCount).toDouble();
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday - 1;
    final hasAnyData = _weekCounts.any((count) => count > 0);

    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 5 ? maxY / 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i > 6) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == today
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: i == today
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(7, (i) {
          final isToday = i == today;
          final value = _weekCounts[i].toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                // Keep a tiny visible bar when there is no data for the week
                // so the chart never looks "missing".
                toY: hasAnyData ? value : 0.06,
                width: 24,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.white.withOpacity(0.06),
                ),
                gradient: LinearGradient(
                  colors: isToday
                      ? [AppColors.primary, AppColors.primary.withOpacity(0.6)]
                      : [
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.1),
                        ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSkillsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills Progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_topSkills.length, (index) {
            final skill = _topSkills[index];
            final percentage = (skill['percentage'] as num?)?.toDouble() ?? 0.0;
            final percentageLabel = percentage.toStringAsFixed(
              percentage.truncateToDouble() == percentage ? 0 : 2,
            );
            final skillName =
                ((skill['skill_name'] as String?)?.trim().isNotEmpty ?? false)
                ? skill['skill_name'] as String
                : (skill['skill_category'] as String? ?? 'General Math');

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        skillName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$percentageLabel%',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (percentage / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 8,
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

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanScreen(cameras: widget.cameras),
          ),
        );
        _loadUserData();
        _loadWeeklyCounts();
        _loadStats();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF3A7BD5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text(
              'Scan Problem',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
