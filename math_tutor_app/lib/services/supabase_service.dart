import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase.dart';
import 'openai_service.dart';

/// Service class for interacting with Supabase backend
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  /// Get the Supabase client instance
  SupabaseClient get client => Supabase.instance.client;

  /// Get the current user
  User? get currentUser => client.auth.currentUser;

  /// Get the current session
  Session? get currentSession => client.auth.currentSession;

  /// Check if user is logged in
  bool get isLoggedIn => currentSession != null;

  /// Initialize Supabase (call this in main.dart)
  static Future<void> initialize() async {
    await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
  }

  // ============== AUTHENTICATION ==============

  /// Sign up a new user with school email
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    // Validate school email
    if (!isValidSchoolEmail(email)) {
      throw Exception(
        'Please use a valid school email address (.k12.in.us or .edu)',
      );
    }

    // Sign up the user with full_name in metadata
    // The database trigger will automatically create the profile row
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName}, // This is used by the database trigger
    );

    // Note: We don't manually insert into profiles anymore.
    // The database trigger (handle_new_user) does it automatically
    // when the user is created in auth.users. This avoids RLS issues.

    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  // ============== USER PROFILE ==============

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;

    final response = await client
        .from('profiles')
        .select()
        .eq('id', currentUser!.id)
        .maybeSingle();

    return response;
  }

  /// Update user profile
  Future<void> updateProfile({String? fullName}) async {
    if (currentUser == null) throw Exception('No user logged in');

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;

    if (updates.isNotEmpty) {
      await client.from('profiles').update(updates).eq('id', currentUser!.id);
    }
  }

  // ============== SKILLS TRACKING ==============

  /// Get all skills for the current user
  Future<List<Map<String, dynamic>>> getUserSkills() async {
    if (currentUser == null) return [];

    final response = await client
        .from('skills')
        .select()
        .eq('user_id', currentUser!.id)
        .order('last_practiced', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get top skills by percentage (for home screen display)
  Future<List<Map<String, dynamic>>> getTopSkills({int limit = 2}) async {
    final skills = await getUserSkills();

    // Percentage should represent distribution of solved/attempted problems
    // across skills, not per-skill accuracy.
    final totalAttempted = skills.fold<int>(
      0,
      (sum, skill) => sum + ((skill['problems_attempted'] as int?) ?? 0),
    );

    // Calculate usage share for each skill.
    final skillsWithPercentage = skills.map((skill) {
      final attempted = (skill['problems_attempted'] as int?) ?? 0;
      final percentage = totalAttempted > 0
          ? (attempted / totalAttempted * 100)
          : 0.0;

      return {...skill, 'percentage': percentage};
    }).toList();

    // Sort by usage share (highest first), then by most recently practiced.
    skillsWithPercentage.sort((a, b) {
      final aPct = (a['percentage'] as num).toDouble();
      final bPct = (b['percentage'] as num).toDouble();
      final pctCmp = bPct.compareTo(aPct);
      if (pctCmp != 0) return pctCmp;

      final aDateRaw = a['last_practiced'];
      final bDateRaw = b['last_practiced'];
      final aDate = aDateRaw is String
          ? DateTime.tryParse(aDateRaw)
          : aDateRaw as DateTime?;
      final bDate = bDateRaw is String
          ? DateTime.tryParse(bDateRaw)
          : bDateRaw as DateTime?;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    // Return top N skills
    return skillsWithPercentage.take(limit).toList();
  }

  /// Update or create a skill record
  Future<void> updateSkill({
    required String skillName,
    required String skillCategory,
    required bool wasSolved,
  }) async {
    if (currentUser == null) throw Exception('No user logged in');

    // Try to get existing skill
    final existing = await client
        .from('skills')
        .select()
        .eq('user_id', currentUser!.id)
        .eq('skill_name', skillName)
        .maybeSingle();

    if (existing != null) {
      // Update existing skill
      await client
          .from('skills')
          .update({
            'problems_attempted': (existing['problems_attempted'] as int) + 1,
            'problems_solved': wasSolved
                ? (existing['problems_solved'] as int) + 1
                : existing['problems_solved'],
            'last_practiced': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id']);
    } else {
      // Create new skill
      await client.from('skills').insert({
        'user_id': currentUser!.id,
        'skill_name': skillName,
        'skill_category': skillCategory,
        'problems_attempted': 1,
        'problems_solved': wasSolved ? 1 : 0,
        'last_practiced': DateTime.now().toIso8601String(),
      });
    }
  }

  // ============== PROBLEM HISTORY ==============

  /// Save a solved problem to history
  Future<void> saveProblemToHistory({
    required String imagePath,
    required List<SolutionBlock> solution,
    String? skillCategory,
    String? skillName,
  }) async {
    if (currentUser == null) throw Exception('No user logged in');

    final solutionJson = solution.map((block) => block.toJson()).toList();

    try {
      await client.from('problem_history').insert({
        'user_id': currentUser!.id,
        'image_path': imagePath,
        'solution_data': solutionJson,
        'skill_category': skillCategory,
        'skill_name': skillName,
        'solved_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      print('SUPABASE INSERT ERROR: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      rethrow;
    }
  }

  /// Get problem history for the current user
  /// Can filter by date
  Future<List<Map<String, dynamic>>> getProblemHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (currentUser == null) return [];

    final response = await client
        .from('problem_history')
        .select()
        .eq('user_id', currentUser!.id)
        .order('solved_at', ascending: false);

    List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(
      response,
    );

    // Filter by date in Dart if needed
    if (startDate != null || endDate != null) {
      final start = startDate?.toLocal();
      final end = endDate?.toLocal();
      results = results.where((problem) {
        final rawSolvedAt = problem['solved_at'];
        DateTime? solvedAt;
        if (rawSolvedAt is DateTime) {
          solvedAt = rawSolvedAt.toLocal();
        } else if (rawSolvedAt is String && rawSolvedAt.isNotEmpty) {
          solvedAt = DateTime.tryParse(rawSolvedAt)?.toLocal();
        }

        if (solvedAt == null) return false;

        if (start != null && solvedAt.isBefore(start)) {
          return false;
        }
        if (end != null && solvedAt.isAfter(end)) {
          return false;
        }
        return true;
      }).toList();
    }

    return results;
  }

  /// Get problems solved today
  Future<List<Map<String, dynamic>>> getTodayProblems() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await getProblemHistory(startDate: startOfDay, endDate: endOfDay);
  }

  /// Delete a problem from history
  Future<void> deleteProblem(String problemId) async {
    if (currentUser == null) throw Exception('No user logged in');

    final parsedId = int.tryParse(problemId);
    final idValue = parsedId ?? problemId;

    await client
        .from('problem_history')
        .delete()
        .eq('user_id', currentUser!.id)
        .eq('id', idValue);
  }

  /// Delete all history
  Future<void> clearAllHistory() async {
    if (currentUser == null) throw Exception('No user logged in');

    await client
        .from('problem_history')
        .delete()
        .eq('user_id', currentUser!.id);
  }

  // ============== STATISTICS ==============

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    if (currentUser == null) {
      return {
        'total_problems': 0,
        'problems_today': 0,
        'problems_this_week': 0,
        'top_skill': null,
      };
    }

    // Get all history
    final allHistory = await getProblemHistory();

    // Get today's problems
    final todayProblems = await getTodayProblems();

    // Get this week's problems
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekProblems = await getProblemHistory(
      startDate: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
    );

    // Get top skill
    final skills = await getTopSkills(limit: 1);
    final topSkill = skills.isNotEmpty ? skills.first : null;

    return {
      'total_problems': allHistory.length,
      'problems_today': todayProblems.length,
      'problems_this_week': weekProblems.length,
      'top_skill': topSkill,
    };
  }
}
