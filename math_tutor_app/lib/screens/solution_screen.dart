import 'package:flutter/material.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import '../constants/colors.dart';
import '../services/openai_service.dart';
import '../widgets/solution_parser.dart';

// Screen that shows the solution to a captured math problem
class SolutionScreen extends StatefulWidget {
  final String imagePath;

  const SolutionScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<SolutionScreen> createState() => _SolutionScreenState();
}

class _SolutionScreenState extends State<SolutionScreen> {
  bool _isLoading = true; // Track if we're still waiting for the AI response
  List<SolutionBlock> _solution = []; // The structured solution blocks from OpenAI
  String _error = ''; // Store any error messages
  final OpenAIService _openAIService = OpenAIService();
  
  // Audio playback state
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isGeneratingAudio = false;
  bool _isPlayingAudio = false;
  String? _audioPath;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Start analyzing as soon as the screen loads
    _analyzeProblem();
    
    // Listen to audio player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlayingAudio = state == PlayerState.playing;
      });
    });
    
    // Listen to audio duration changes
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _audioDuration = duration;
      });
    });
    
    // Listen to audio position changes
    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _audioPosition = position;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // Clean up the audio file if it exists
    if (_audioPath != null) {
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

      setState(() {
        _solution = solution;
        _isLoading = false;
      });
    } catch (e) {
      // If something goes wrong, show the error instead
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Generates audio explanation of the solution
  Future<void> _generateAndPlayAudio() async {
    if (_solution.isEmpty) return;
    
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
    setState(() {
      _audioPosition = Duration.zero;
    });
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
        title: const Text('Solution'),
        actions: [
          // Audio button in the app bar
          if (!_isLoading && _solution.isNotEmpty && _error.isEmpty)
            _buildAudioButton(),
        ],
      ),
      body: _isLoading
          ? // Show loading spinner while we wait for the AI
          const Center(
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
          : // Once loaded, show the solution
          Column(
              children: [
                // Audio player controls (shown when audio is loaded)
                if (_audioPath != null) _buildAudioPlayerControls(),
                
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show the captured image at the top so they can see what problem we solved
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(File(widget.imagePath)),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Either show an error box or the actual solution
                        if (_error.isNotEmpty)
                          _buildErrorBox()
                        else
                          // Map each solution block to a widget and display them
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _solution
                                .map(SolutionParser.buildSolutionBlock)
                                .toList(),
                          ),

                        const SizedBox(height: 24),

                        // Button to go back and solve another problem
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Pop twice to go back to the home screen
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
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Builds the audio button for the app bar
  Widget _buildAudioButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: _isGeneratingAudio
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Icon(
                  _isPlayingAudio ? Icons.pause : Icons.volume_up,
                  color: AppColors.primary,
                ),
          onPressed: _isGeneratingAudio ? null : _toggleAudioPlayback,
          tooltip: 'Listen to explanation',
        ),
      ),
    );
  }

  /// Builds the audio player controls bar
  Widget _buildAudioPlayerControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
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
          Row(
            children: [
              // Play/Pause button
              IconButton(
                icon: Icon(
                  _isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 40,
                  color: AppColors.primary,
                ),
                onPressed: _toggleAudioPlayback,
              ),
              
              const SizedBox(width: 8),
              
              // Progress bar and time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_audioPosition),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(_audioDuration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Stop button
              IconButton(
                icon: const Icon(
                  Icons.stop_circle_outlined,
                  size: 32,
                  color: Colors.white70,
                ),
                onPressed: _stopAudio,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formats duration to MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Builds a red error box with helpful troubleshooting tips
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
          // Show the actual error message
          Text(
            _error,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          // Give them some hints on what might be wrong
          const Text(
            'Please make sure you have\n'
            '1. Set your OpenAI API key\n'
            '2. Sufficient OpenAI credits\n'
            '3. Proper internet connection',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}