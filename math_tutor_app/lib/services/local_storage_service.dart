import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'openai_service.dart';

/// Service for local storage of problem history
/// This provides offline access and faster loading
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // Broadcasts profile image path changes so UI (Home/Settings) can stay in sync.
  final ValueNotifier<String?> profileImagePathNotifier =
      ValueNotifier<String?>(null);

  static const String _historyKey = 'problem_history';
  static const String _userKey = 'current_user';

  /// Save current user data locally
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
  }

  /// Get current user data from local storage
  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    return jsonDecode(userJson) as Map<String, dynamic>;
  }

  /// Clear user data (on logout)
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    profileImagePathNotifier.value = null;
  }

  /// Save/update profile image path in local user data.
  Future<void> setProfileImagePath(String? imagePath) async {
    final current = await getUserData() ?? <String, dynamic>{};

    if (imagePath == null || imagePath.isEmpty) {
      current.remove('profile_image_path');
      profileImagePathNotifier.value = null;
    } else {
      current['profile_image_path'] = imagePath;
      profileImagePathNotifier.value = imagePath;
    }

    await saveUserData(current);
  }

  /// Read profile image path from local user data.
  Future<String?> getProfileImagePath() async {
    final data = await getUserData();
    final imagePath = data?['profile_image_path'] as String?;
    if (profileImagePathNotifier.value != imagePath) {
      profileImagePathNotifier.value = imagePath;
    }
    return imagePath;
  }

  /// Save problem to local history
  Future<void> saveProblemLocally({
    required String id,
    required String imagePath,
    String? audioPath,
    required List<SolutionBlock> solution,
    String? skillCategory,
    String? skillName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing history
    final historyJson = prefs.getString(_historyKey);
    final List<dynamic> history = historyJson != null
        ? jsonDecode(historyJson) as List<dynamic>
        : [];

    // Create new problem entry
    final problemData = {
      'id': id,
      'imagePath': imagePath,
      'audioPath': audioPath,
      'solution': solution.map((block) => block.toJson()).toList(),
      'skillCategory': skillCategory,
      'skillName': skillName,
      'solvedAt': DateTime.now().toIso8601String(),
    };

    // Add to history
    history.insert(0, problemData); // Add to beginning

    // Save back to preferences
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  /// Update an existing problem in local history
  Future<void> updateProblemLocally(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    if (historyJson == null) return;

    final List<dynamic> history = jsonDecode(historyJson) as List<dynamic>;
    final index = history.indexWhere(
      (p) => (p as Map<String, dynamic>)['id'] == id,
    );
    if (index == -1) return;

    final current = Map<String, dynamic>.from(history[index] as Map);
    current.addAll(updates);
    history[index] = current;

    await prefs.setString(_historyKey, jsonEncode(history));
  }

  /// Get all problems from local history
  Future<List<Map<String, dynamic>>> getLocalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);

    if (historyJson == null) return [];

    final List<dynamic> history = jsonDecode(historyJson) as List<dynamic>;
    return history.cast<Map<String, dynamic>>();
  }

  /// Get problems solved today from local history
  Future<List<Map<String, dynamic>>> getTodayProblemsLocally() async {
    final allHistory = await getLocalHistory();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return allHistory.where((problem) {
      final solvedAt = DateTime.parse(problem['solvedAt'] as String);
      return solvedAt.isAfter(startOfDay);
    }).toList();
  }

  /// Get a specific problem by ID
  Future<Map<String, dynamic>?> getProblemById(String id) async {
    final history = await getLocalHistory();
    try {
      return history.firstWhere((problem) => problem['id'] == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a problem from local history
  Future<void> deleteProblemLocally(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getLocalHistory();

    history.removeWhere((problem) => problem['id'] == id);

    await prefs.setString(_historyKey, jsonEncode(history));
  }

  /// Clear all local history
  Future<void> clearLocalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// Parse solution blocks from JSON
  List<SolutionBlock> parseSolutionBlocks(List<dynamic> solutionJson) {
    return solutionJson
        .map((block) => SolutionBlock.fromJson(block as Map<String, dynamic>))
        .toList();
  }
}
