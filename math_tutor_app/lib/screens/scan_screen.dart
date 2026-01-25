import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../constants/colors.dart';
import 'solution_screen.dart';

class ScanScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ScanScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _controller!.takePicture();
      
      if (mounted) {
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
          IconButton(
            icon: const Icon(Icons.flash_off),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
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
