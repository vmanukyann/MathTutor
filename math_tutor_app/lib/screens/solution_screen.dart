import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/colors.dart';
import '../services/openai_service.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';
import 'dart:async';


// Screen that shows the solution to a captured math problem
class SolutionScreen extends StatefulWidget {
  final String imagePath;

  const SolutionScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<SolutionScreen> createState() => _SolutionScreenState();
}

class _SolutionScreenState extends State<SolutionScreen> {
  bool _isLoading = true;
  List<SolutionBlock> _solution = [];
  String _error = '';
  final OpenAIService _openAIService = OpenAIService();
  final LocalStorageService _localStorage = LocalStorageService();
  final SupabaseService _supabaseService = SupabaseService();
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  // Audio playback state
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isGeneratingAudio = false;
  bool _isPlayingAudio = false;
  String? _audioPath;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  // Random motivational quote
  late String _motivationalQuote;
  
  // Track which steps are expanded
  final Map<int, bool> _expandedSteps = {};

  // Auto-save tracking
  bool _hasAutoSaved = false;
  String? _savedProblemId;

  // List of motivational quotes
  static const List<String> _quotes = [
    "Let's work this out!",
    "Time to solve this together!",
    "Let's break this down step by step!",
    "You've got this! Let's go!",
    "Here's how we solve it!",
    "Let's figure this out together!",
  ];

  @override
  void initState() {
    super.initState();
    // Pick a random quote
    _motivationalQuote = _quotes[Random().nextInt(_quotes.length)];
    
    // Start analyzing as soon as the screen loads
    _analyzeProblem();
    
    // Listen to audio player state changes
    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlayingAudio = state == PlayerState.playing;
      });
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _audioDuration = duration;
      });
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _audioPosition = position;
      });
    });
  }

@override
void dispose() {
  // Cancel stream listeners FIRST
  _playerStateSub?.cancel();
  _durationSub?.cancel();
  _positionSub?.cancel();

  _audioPlayer.dispose();

  // Only clean up audio file if it's not saved to history (temp file)
  if (_audioPath != null && !_hasAutoSaved) {
    try {
      File(_audioPath!).deleteSync();
    } catch (_) {}
  }

  super.dispose();
}


  /// Sends the image to OpenAI and gets back the solution
  Future<void> _analyzeProblem() async {
    try {
      final solution =
          await _openAIService.analyzeMathProblem(widget.imagePath);

      if (!mounted) return;
      setState(() {
        _solution = solution;
        _isLoading = false;
      });

      // Auto-save to history after successfully getting solution
      await _autoSaveToHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }

  }

  /// Generates audio explanation of the solution
  Future<void> _generateAndPlayAudio() async {
    if (_solution.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isGeneratingAudio = true;
    });

    try {
      // If we already have audio, just play it
      if (_audioPath != null) {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
      } else {
        // Generate new audio
        final audioPath = await _openAIService.generateAudioExplanation(_solution);

        if (!mounted) return;
        setState(() {
          _audioPath = audioPath;
        });

        // Play the audio
        await _audioPlayer.play(DeviceFileSource(audioPath));
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isGeneratingAudio = false;
      });
    }
  }

  /// Toggles audio playback (play/pause)
  Future<void> _toggleAudioPlayback() async {
    if (_isPlayingAudio) {
      await _audioPlayer.pause();
    } else if (_audioPath != null) {
      await _audioPlayer.resume();
    } else {
      await _generateAndPlayAudio();
    }
  }

  /// Stops audio playback
  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _audioPosition = Duration.zero;
    });
  }

  /// Groups solution blocks into steps
  List<Map<String, dynamic>> _groupIntoSteps() {
    List<Map<String, dynamic>> steps = [];
    Map<String, dynamic>? currentStep;

    for (var block in _solution) {
      // Skip the main "Solution" header
      if (block.type == 'header' && block.text.toLowerCase() == 'solution') {
        continue;
      }

      // If it's a step header, start a new step
      if (block.type == 'header' && 
          (block.text.toLowerCase().contains('step') || 
           block.text.toLowerCase().startsWith('step'))) {
        // Save previous step if exists
        if (currentStep != null) {
          steps.add(currentStep);
        }
        // Start new step
        currentStep = {
          'title': block.text,
          'blocks': <SolutionBlock>[],
        };
      } else if (currentStep != null) {
        // Add block to current step
        (currentStep['blocks'] as List<SolutionBlock>).add(block);
      }
    }

    // Add the last step
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 20),
                  Text(
                    'Analyzing problem...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Motivational Quote
                  Text(
                    _motivationalQuote,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 30),

                  // Audio Button (Centered)
                  if (_error.isEmpty && _solution.isNotEmpty)
                    _buildCenteredAudioButton(),

                  const SizedBox(height: 20),

                  // Audio Player Controls (when audio is playing)
                  if (_audioPath != null) _buildAudioPlayerControls(),

                  const SizedBox(height: 30),

                  // Error Box or Solution Steps
                  if (_error.isNotEmpty)
                    _buildErrorBox()
                  else
                    _buildStepsDropdown(),

                  const SizedBox(height: 30),

                  // Button to solve another problem
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Solve Another Problem',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Builds the centered audio button
  Widget _buildCenteredAudioButton() {
    return Center(
      child: Container(
        width: 200,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _isGeneratingAudio ? null : _toggleAudioPlayback,
            child: Center(
              child: _isGeneratingAudio
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPlayingAudio ? Icons.pause : Icons.volume_up,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isPlayingAudio ? 'Pause' : 'Listen',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the audio player controls
  Widget _buildAudioPlayerControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _audioPosition.inSeconds.toDouble(),
              max: _audioDuration.inSeconds.toDouble(),
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey[700],
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
              },
            ),
          ),
          
          // Time display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_audioPosition),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatDuration(_audioDuration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the steps with dropdown/expansion
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
              // Step Header (clickable)
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
                      // Expand/Collapse Icon
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      
                      // Step Title
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
              
              // Step Content (expandable)
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

  /// Builds individual solution blocks
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
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Math.tex(
              block.text,
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
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
            border: Border.all(
              color: Colors.amber.withOpacity(0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.help_outline,
                color: Colors.amber,
                size: 20,
              ),
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

  /// Persists a file to the history directory
  Future<String> _persistFileToHistoryDir(String sourcePath, String destFileName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${docsDir.path}/mathtutor_history');
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    final destPath = '${historyDir.path}/$destFileName';
    return (await File(sourcePath).copy(destPath)).path;
  }

  /// Auto-saves solution, image, and audio to history
Future<void> _autoSaveToHistory() async {
  if (_hasAutoSaved || _solution.isEmpty || _error.isNotEmpty) return;

  final id = DateTime.now().millisecondsSinceEpoch.toString();
  _savedProblemId = id;

  try {
    // 1) Persist image
    final imageExt =
        widget.imagePath.contains('.') ? widget.imagePath.split('.').last : 'jpg';
    final savedImagePath =
        await _persistFileToHistoryDir(widget.imagePath, 'img_$id.$imageExt');

    // 2) SAVE IMMEDIATELY (so History shows it even if user leaves)
    await _localStorage.saveProblemLocally(
      id: id,
      imagePath: savedImagePath,
      audioPath: null, // audio comes later
      solution: _solution,
    );

    _hasAutoSaved = true;

    // 3) Save to Supabase (optional, don't block local history)
    if (_supabaseService.isLoggedIn) {
      try {
        await _supabaseService.saveProblemToHistory(
          imagePath: savedImagePath,
          solution: _solution,
        );
      } catch (e) {
        print('Error saving to Supabase: $e');
      }
    }

    // 4) Generate audio AFTER saving (optional enhancement)
    if (mounted) setState(() => _isGeneratingAudio = true);

    final tempAudioPath = await _openAIService.generateAudioExplanation(_solution);
    final savedAudioPath =
        await _persistFileToHistoryDir(tempAudioPath, 'audio_$id.mp3');

    try {
      await File(tempAudioPath).delete();
    } catch (_) {}

    // Update local entry to include audio
    await _localStorage.updateProblemLocally(id, {'audioPath': savedAudioPath});

    // Update UI only if still on screen
    if (mounted) {
      setState(() {
        _audioPath = savedAudioPath;
        _isGeneratingAudio = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Saved to History'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    print('Error auto-saving to history: $e');
    if (mounted) {
      setState(() => _isGeneratingAudio = false);
    }
  }
}


  /// Formats duration to MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Builds error box
  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Error',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _error,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'An error occured while processing your problem\n'
            'Please make sure you have proper internet connections\n',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}