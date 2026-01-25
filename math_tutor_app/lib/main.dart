import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        primaryColor: const Color(0xFF2463EB),
      ),
      home: MainNavigation(cameras: cameras),
    );
  }
}