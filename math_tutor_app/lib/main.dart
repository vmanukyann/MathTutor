import 'package:flutter/material.dart';

void main() {
  runApp(const MathTutorApp());
}

class MathTutorApp extends StatelessWidget {
  const MathTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Tutor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MathTutorHomePage(),
    );
  }
}

class MathTutorHomePage extends StatefulWidget {
  const MathTutorHomePage({super.key});

  @override
  State<MathTutorHomePage> createState() => _MathTutorHomePageState();
}

class _MathTutorHomePageState extends State<MathTutorHomePage> {
  String? _selectedImagePath;
  bool _isProcessing = false;
  bool _hasAudioResponse = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Math Tutor'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              const SizedBox(height: 20),
              const Icon(
                Icons.calculate,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 10),
              const Text(
                'Upload Your Math Problem',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Take a photo or upload an image of your math problem and get step-by-step guidance!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Image Preview Section
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                ),
                child: _selectedImagePath == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 60,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No image selected',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(
                          _selectedImagePath!,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(height: 30),

              // Upload Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement camera functionality
                        print('Take Photo button pressed');
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement gallery picker
                        print('Upload Image button pressed');
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Upload Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Process Button
              ElevatedButton.icon(
                onPressed: _selectedImagePath == null || _isProcessing
                    ? null
                    : () {
                        // TODO: Implement AI processing
                        setState(() {
                          _isProcessing = true;
                        });
                        print('Solve Problem button pressed');
                        // Simulate processing
                        Future.delayed(const Duration(seconds: 2), () {
                          setState(() {
                            _isProcessing = false;
                            _hasAudioResponse = true;
                          });
                        });
                      },
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.psychology),
                label: Text(_isProcessing ? 'Processing...' : 'Solve Problem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Response Section
              if (_hasAudioResponse) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue[200]!, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 10),
                          Text(
                            'Solution Ready!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Your step-by-step solution has been generated with voice guidance.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement audio playback
                                print('Play Audio button pressed');
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play Audio'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement text view
                                print('View Text button pressed');
                              },
                              icon: const Icon(Icons.text_fields),
                              label: const Text('View Text'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Clear Button
              if (_selectedImagePath != null || _hasAudioResponse)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImagePath = null;
                      _hasAudioResponse = false;
                      _isProcessing = false;
                    });
                    print('Clear All button pressed');
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}