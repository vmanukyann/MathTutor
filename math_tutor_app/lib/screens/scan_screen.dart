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
  bool _isProcessing = false;

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
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
      ),
      body: Stack(
        children: [
          // Camera preview fills the entire screen
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Dark overlay with transparent square cutout
          Positioned.fill(
            child: CustomPaint(
              painter: ScanOverlayPainter(),
            ),
          ),
          
          // Corner brackets overlay
          Center(
            child: _buildCornerBrackets(),
          ),
          
          // Instruction text
          const Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Position the math problem',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'within the frame',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom instruction
          Positioned(
            bottom: 150,
            left: 0,
            right: 0,
            child: Text(
              'Only content inside the box will be scanned',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 10,
                  ),
                ],
              ),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(15),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
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

  /// Builds the corner bracket frame
  Widget _buildCornerBrackets() {
    final screenSize = MediaQuery.of(context).size;
    final frameWidth = screenSize.width * 0.85;
    final frameHeight = frameWidth * 0.75; // 4:3 aspect ratio
    final cornerLength = 40.0;
    final cornerThickness = 4.0;

    return SizedBox(
      width: frameWidth,
      height: frameHeight,
      child: Stack(
        children: [
          // Top-left corner
          Positioned(
            top: 0,
            left: 0,
            child: _buildCorner(
              cornerLength: cornerLength,
              thickness: cornerThickness,
              isTopLeft: true,
            ),
          ),
          // Top-right corner
          Positioned(
            top: 0,
            right: 0,
            child: _buildCorner(
              cornerLength: cornerLength,
              thickness: cornerThickness,
              isTopRight: true,
            ),
          ),
          // Bottom-left corner
          Positioned(
            bottom: 0,
            left: 0,
            child: _buildCorner(
              cornerLength: cornerLength,
              thickness: cornerThickness,
              isBottomLeft: true,
            ),
          ),
          // Bottom-right corner
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildCorner(
              cornerLength: cornerLength,
              thickness: cornerThickness,
              isBottomRight: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single corner bracket
  Widget _buildCorner({
    required double cornerLength,
    required double thickness,
    bool isTopLeft = false,
    bool isTopRight = false,
    bool isBottomLeft = false,
    bool isBottomRight = false,
  }) {
    return CustomPaint(
      size: Size(cornerLength, cornerLength),
      painter: CornerPainter(
        color: AppColors.primary,
        thickness: thickness,
        isTopLeft: isTopLeft,
        isTopRight: isTopRight,
        isBottomLeft: isBottomLeft,
        isBottomRight: isBottomRight,
      ),
    );
  }
}

/// Custom painter for the corner brackets
class CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isTopLeft;
  final bool isTopRight;
  final bool isBottomLeft;
  final bool isBottomRight;

  CornerPainter({
    required this.color,
    required this.thickness,
    this.isTopLeft = false,
    this.isTopRight = false,
    this.isBottomLeft = false,
    this.isBottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isTopLeft) {
      // Top-left corner: L shape
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else if (isTopRight) {
      // Top-right corner: mirrored L
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (isBottomLeft) {
      // Bottom-left corner: upside-down L
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (isBottomRight) {
      // Bottom-right corner: upside-down mirrored L
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for the dark overlay with transparent cutout
class ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = size.width * 0.85;
    final frameHeight = frameWidth * 0.75; // 4:3 aspect ratio
    
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    
    final scanRect = Rect.fromLTWH(left, top, frameWidth, frameHeight);
    
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6);
    
    // Draw dark overlay
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Cut out the scan area
    path.addRRect(
      RRect.fromRectAndRadius(
        scanRect,
        const Radius.circular(12),
      ),
    );
    
    path.fillType = PathFillType.evenOdd;
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}