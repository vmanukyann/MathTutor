import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'services/supabase_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';

/// Entry point of the app
void main() async {
  // Initialize Flutter bindings before using async in main
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseService.initialize();
  
  // Get the list of available cameras on the device
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
      debugShowCheckedModeBanner: false,
      
      // Dark theme to match our design
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        primaryColor: const Color(0xFF2463EB),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF2463EB),
          secondary: const Color(0xFF2463EB),
          surface: const Color(0xFF1C1F35),
        ),
      ),
      
      // Use AuthChecker to determine initial screen
      home: AuthChecker(cameras: cameras),
    );
  }
}

/// Widget that checks authentication status and routes accordingly
class AuthChecker extends StatefulWidget {
  final List<CameraDescription> cameras;

  const AuthChecker({Key? key, required this.cameras}) : super(key: key);

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Check if user is already logged in
    final isLoggedIn = _supabaseService.isLoggedIn;
    
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2463EB),
          ),
        ),
      );
    }

    // Route to main navigation if logged in, otherwise to login screen
    if (_isLoggedIn) {
      return MainNavigation(cameras: widget.cameras);
    } else {
      return LoginScreen(cameras: widget.cameras);
    }
  }
}
