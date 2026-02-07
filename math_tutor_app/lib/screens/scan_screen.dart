import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../constants/colors.dart';
import 'solution_screen.dart';

// Camera screen where users can scan math problems
class ScanScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ScanScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  bool _isProcessing = false; // Prevent multiple captures at once

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  /// Initialize the camera when the screen loads
  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    
    // Use the first camera (usually the back camera)
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high, // High quality for better text recognition
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() {}); // Rebuild to show the camera preview
    }
  }

  @override
  void dispose() {
    // Clean up the camera controller when leaving the screen
    _controller?.dispose();
    super.dispose();
  }

  /// Takes a picture and navigates to the solution screen
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Capture the image
      final image = await _controller!.takePicture();
      
      if (mounted) {
        // Navigate to solution screen with the captured image
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SolutionScreen(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      print('Error taking picture: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner while camera initializes
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan Problem'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Flash button - not implemented yet but left for future
          IconButton(
            icon: const Icon(Icons.flash_off),
            onPressed: () {
              // TODO: toggle flash
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview fills the entire screen
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Focus frame overlay - helps users align the problem
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          // Instruction text
          const Positioned(
            bottom: 150,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Align problem within the',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  'frame',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Camera shutter button at the bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}