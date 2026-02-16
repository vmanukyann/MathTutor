import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../constants/colors.dart';
import '../services/openai_service.dart';
import '../services/local_storage_service.dart';
import 'package:audioplayers/audioplayers.dart';

/// Screen that displays a saved problem from history
/// Shows the original image and the solution
class SolutionDetailScreen extends StatefulWidget {
  final String problemId;
  final String imagePath;
  final String? audioPath;
  final List<SolutionBlock> solution;

  const SolutionDetailScreen({
    Key? key,
    required this.problemId,
    required this.imagePath,
    this.audioPath,
    required this.solution,
  }) : super(key: key);

  @override
  State<SolutionDetailScreen> createState() => _SolutionDetailScreenState();
}

class _SolutionDetailScreenState extends State<SolutionDetailScreen> {
  final _localStorage = LocalStorageService();
  final _openAIService = OpenAIService();

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isGeneratingAudio = false;
  bool _isPlayingAudio = false;
  PlayerState _playerState = PlayerState.stopped;
  String? _audioPath;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  // Expanded steps tracking
  final Map<int, bool> _expandedSteps = {};

  @override
  void initState() {
    super.initState();

    // Use the provided audio path if available
    _audioPath = widget.audioPath;

    // Setup audio listeners
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        _isPlayingAudio = state == PlayerState.playing;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _audioDuration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _audioPosition = position;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // Don't delete audio files - they're saved to history directory
    super.dispose();
  }

  /// Generate and play audio explanation
  Future<void> _generateAndPlayAudio() async {
    if (widget.solution.isEmpty) return;

    setState(() {
      _isGeneratingAudio = true;
    });

    try {
      if (_audioPath != null && await File(_audioPath!).exists()) {
        // Audio already exists, just play it
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
      } else {
        // Generate new audio
        final tempAudioPath = await _openAIService.generateAudioExplanation(
          widget.solution,
        );

        // Persist to history directory
        final docsDir = await getApplicationDocumentsDirectory();
        final historyDir = Directory('${docsDir.path}/mathtutor_history');
        if (!await historyDir.exists()) {
          await historyDir.create(recursive: true);
        }
        final savedAudioPath =
            '${historyDir.path}/audio_${widget.problemId}.mp3';
        await File(tempAudioPath).copy(savedAudioPath);

        // Delete temp file
        try {
          await File(tempAudioPath).delete();
        } catch (_) {}

        setState(() {
          _audioPath = savedAudioPath;
        });

        // Update history entry with audio path
        await _localStorage.updateProblemLocally(widget.problemId, {
          'audioPath': savedAudioPath,
        });

        await _audioPlayer.play(DeviceFileSource(savedAudioPath));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isGeneratingAudio = false;
      });
    }
  }

  Future<void> _toggleAudioPlayback() async {
    if (_isPlayingAudio) {
      await _audioPlayer.pause();
    } else if (_audioPath != null && await File(_audioPath!).exists()) {
      if (_playerState == PlayerState.paused) {
        await _audioPlayer.resume();
      } else {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
      }
    } else {
      await _generateAndPlayAudio();
    }
  }

  Future<void> _deleteProblem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete Problem?',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: const Text(
          'This will remove this problem from your history.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _localStorage.deleteProblemLocally(widget.problemId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  List<Map<String, dynamic>> _groupIntoSteps() {
    List<Map<String, dynamic>> steps = [];
    Map<String, dynamic>? currentStep;

    for (var block in widget.solution) {
      if (block.type == 'header' && block.text.toLowerCase() == 'solution') {
        continue;
      }

      if (block.type == 'header' &&
          (block.text.toLowerCase().contains('step') ||
              block.text.toLowerCase().startsWith('step'))) {
        if (currentStep != null) {
          steps.add(currentStep);
        }
        currentStep = {'title': block.text, 'blocks': <SolutionBlock>[]};
      } else if (currentStep != null) {
        (currentStep['blocks'] as List<SolutionBlock>).add(block);
      }
    }

    if (currentStep != null && (currentStep['blocks'] as List).isNotEmpty) {
      steps.add(currentStep);
    }

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Solution'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteProblem,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original problem image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 300),
                color: Colors.black,
                child: File(widget.imagePath).existsSync()
                    ? Image.file(File(widget.imagePath), fit: BoxFit.contain)
                    : Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              color: AppColors.textGrey,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Image not found',
                              style: TextStyle(color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Audio button
            Center(
              child: ElevatedButton.icon(
                onPressed: _isGeneratingAudio ? null : _toggleAudioPlayback,
                icon: _isGeneratingAudio
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isPlayingAudio ? Icons.pause : Icons.play_arrow),
                label: Text(
                  _isGeneratingAudio
                      ? 'Generating...'
                      : _isPlayingAudio
                      ? 'Pause Explanation'
                      : 'Play Explanation',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),

            // Audio progress
            if (_audioPath != null) ...[
              const SizedBox(height: 16),
              _buildAudioProgress(),
            ],

            const SizedBox(height: 32),

            // Solution steps
            const Text(
              'Solution',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),

            const SizedBox(height: 16),

            _buildStepsDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioProgress() {
    final maxSeconds = _audioDuration.inSeconds > 0
        ? _audioDuration.inSeconds.toDouble()
        : 1.0;
    final currentSeconds = _audioPosition.inSeconds.toDouble().clamp(
      0.0,
      maxSeconds,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Slider(
            value: currentSeconds,
            max: maxSeconds,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.textGrey.withOpacity(0.3),
            onChanged: (value) async {
              await _audioPlayer.seek(Duration(seconds: value.toInt()));
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_audioPosition),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                _formatDuration(_audioDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepsDropdown() {
    final steps = _groupIntoSteps();

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final stepTitle = step['title'] as String;
        final stepBlocks = step['blocks'] as List<SolutionBlock>;
        final isExpanded = _expandedSteps[index] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpanded ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedSteps[index] = !isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stepTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isExpanded)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: stepBlocks.map((block) {
                      return _buildSolutionBlock(block);
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSolutionBlock(SolutionBlock block) {
    switch (block.type) {
      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        );

      case 'equation':
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Center(
            child: Math.tex(
              block.text,
              textStyle: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        );

      case 'question':
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_outline, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.text,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
