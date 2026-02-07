import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/main_navigation.dart';

// Entry point of the app
void main() async {
  // Need to initialize Flutter bindings before using async in main
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get the list of available cameras on the device
  // We'll pass this to the scan screen so it can use the camera
  final cameras = await availableCameras();
  
  runApp(MathTutorApp(cameras: cameras));
}

class MathTutorApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MathTutorApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MathTutor',
      // Dark theme to match our design
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E27), // Dark blue background
        primaryColor: const Color(0xFF2463EB), // Blue accent color
      ),
      home: MainNavigation(cameras: cameras),
    );
  }
}