import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../services/local_storage_service.dart';
import '../services/openai_service.dart';
import 'solution_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _localStorage = LocalStorageService();
  List<Map<String, dynamic>> _allHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _localStorage.getLocalHistory();
      
      setState(() {
        _allHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Groups problems by date (Today, Yesterday, This Week, etc.)
  Map<String, List<Map<String, dynamic>>> _groupByDate() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: now.weekday - 1));

    for (final problem in _allHistory) {
      final solvedAt = DateTime.parse(problem['solvedAt'] as String);
      final solvedDate = DateTime(solvedAt.year, solvedAt.month, solvedAt.day);
      
      String groupKey;
      if (solvedDate == today) {
        groupKey = 'Today';
      } else if (solvedDate == yesterday) {
        groupKey = 'Yesterday';
      } else if (solvedDate.isAfter(thisWeekStart) || solvedDate == thisWeekStart) {
        groupKey = 'This Week';
      } else {
        groupKey = DateFormat('MMMM d, y').format(solvedDate);
      }
      
      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }
      grouped[groupKey]!.add(problem);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: null,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_allHistory.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 100,
                color: AppColors.textGrey.withOpacity(0.3),
              ),
              const SizedBox(height: 24),
              const Text(
                'No History Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Your solved problems will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textGrey.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groupedHistory = _groupByDate();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear') {
                _showClearHistoryDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All History', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedHistory.length,
          itemBuilder: (context, index) {
            final groupKey = groupedHistory.keys.elementAt(index);
            final problems = groupedHistory[groupKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12, top: index == 0 ? 0 : 16),
                  child: Text(
                    groupKey,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                
                // Problems for this date
                ...problems.map((problem) => _buildProblemCard(problem)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProblemCard(Map<String, dynamic> problem) {
    final solvedAt = DateTime.parse(problem['solvedAt'] as String);
    final timeStr = DateFormat('h:mm a').format(solvedAt);
    final imagePath = problem['imagePath'] as String;
    final skillCategory = problem['skillCategory'] as String?;
    
    // Parse solution to get first equation or text
    final solutionJson = problem['solution'] as List<dynamic>;
    final solution = _localStorage.parseSolutionBlocks(solutionJson);
    
    // Find first meaningful content
    String preview = 'Tap to view solution';
    for (final block in solution) {
      if (block.type == 'equation' && block.text.isNotEmpty) {
        preview = block.text;
        if (preview.length > 40) {
          preview = '${preview.substring(0, 40)}...';
        }
        break;
      } else if (block.type == 'paragraph' && block.text.isNotEmpty) {
        preview = block.text;
        if (preview.length > 50) {
          preview = '${preview.substring(0, 50)}...';
        }
        break;
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SolutionDetailScreen(
              problemId: problem['id'] as String,
              imagePath: imagePath,
              solution: solution,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Problem image thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.black,
                child: File(imagePath).existsSync()
                    ? Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.image_not_supported,
                        color: AppColors.textGrey,
                      ),
              ),
            ),
            
            // Problem details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Skill category (if available)
                    if (skillCategory != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          skillCategory,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    
                    // Preview text
                    Text(
                      preview,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Time
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: AppColors.textGrey.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Arrow icon
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textGrey,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Clear All History?',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: const Text(
          'This will delete all your saved problems. This action cannot be undone.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              await _localStorage.clearLocalHistory();
              Navigator.pop(context);
              _loadHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('History cleared'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
