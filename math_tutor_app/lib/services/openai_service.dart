import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../constants/api.dart';

/// Represents a single block of content in the solution
/// Can be a header, paragraph, equation, or question
class SolutionBlock {
  final String type; // header | paragraph | equation | question
  final String text;

  SolutionBlock({required this.type, required this.text});

  // Creates a SolutionBlock from JSON response
  factory SolutionBlock.fromJson(Map<String, dynamic> json) {
    return SolutionBlock(
      type: (json['type'] ?? 'paragraph').toString(),
      text: (json['text'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
    };
  }
}

class OpenAIService {
  /// Main function that takes an image path and sends it to GPT-4o for analysis
  /// Returns a list of structured solution blocks that we can render nicely
  Future<List<SolutionBlock>> analyzeMathProblem(String imagePath) async {
    try {
      // Read the image file and convert it to base64
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Make the API call to OpenAI
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $OPENAI_API_KEY',
        },
        body: jsonEncode({
          'model': 'gpt-5.2', 
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': _structuredPrompt(),
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'max_completion_tokens': 3000,
        }),
      );

      // Check if the request was successful
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error']?['message'] ?? 'Failed to analyze problem',
        );
      }

      // Extract the response content
      final data = jsonDecode(response.body);
      String rawContent = data['choices'][0]['message']['content'] ?? '';

      // Clean up any code fences or extra formatting
      rawContent = _stripCodeFences(rawContent);

      // Parse the JSON response into our structured blocks
      return _parseStructuredResponse(rawContent);
    } catch (e) {
      throw Exception('Error analyzing math problem: $e');
    }
  }

  /// Generates audio explanation of the solution using OpenAI TTS
  /// Returns the path to the saved audio file
  Future<String> generateAudioExplanation(List<SolutionBlock> solution) async {
    try {
      // Convert the solution blocks into a natural, kid-friendly explanation
      final explanationText = _convertSolutionToSpeech(solution);

      // Make the API call to OpenAI TTS
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $OPENAI_API_KEY',
        },
        body: jsonEncode({
          'model': 'tts-1', // Use tts-1 for faster generation, tts-1-hd for higher quality
          'input': explanationText,
          'voice': 'nova', // Nova is a friendly, clear voice good for education
          'speed': 0.9, // Slightly slower for better comprehension
        }),
      );

      // Check if the request was successful
      if (response.statusCode != 200) {
        final errorData = response.body;
        throw Exception('Failed to generate audio: $errorData');
      }

      // Save the audio file to a temporary location
      final tempDir = Directory.systemTemp;
      final audioFile = File('${tempDir.path}/math_explanation_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await audioFile.writeAsBytes(response.bodyBytes);

      return audioFile.path;
    } catch (e) {
      throw Exception('Error generating audio: $e');
    }
  }

  /// Converts solution blocks into a natural speech text
  /// Removes LaTeX and makes it sound conversational for a kid
  String _convertSolutionToSpeech(List<SolutionBlock> solution) {
    final buffer = StringBuffer();
    
    buffer.writeln("Hi there! Let me walk you through this problem step by step.");
    buffer.writeln(); // Short pause

    for (var block in solution) {
      switch (block.type) {
        case 'header':
          // Skip the main "Solution" header, but announce step headers
          if (!block.text.toLowerCase().contains('solution')) {
            buffer.writeln(block.text);
            buffer.writeln(); // Pause after header
          }
          break;
        
        case 'paragraph':
          // Add the explanation text as-is
          buffer.writeln(block.text);
          break;
        
        case 'equation':
          // Convert LaTeX to spoken math
          final spokenEquation = _convertLatexToSpeech(block.text);
          buffer.writeln(spokenEquation);
          break;
        
        case 'question':
          // Add a slight emphasis to questions
          buffer.writeln(block.text);
          buffer.writeln(); // Pause after question
          break;
      }
    }

    buffer.writeln("And that's how we solve it! Do you have any questions?");
    
    return buffer.toString();
  }

  /// Converts LaTeX equations to speakable text
  /// Example: "-2x \\leq 8" becomes "negative 2 x is less than or equal to 8"
  String _convertLatexToSpeech(String latex) {
    String spoken = latex;

    // Remove LaTeX escapes
    spoken = spoken.replaceAll(r'\\', r'\');
    
    // Replace common math symbols
    spoken = spoken.replaceAll(r'\leq', ' is less than or equal to ');
    spoken = spoken.replaceAll(r'\geq', ' is greater than or equal to ');
    spoken = spoken.replaceAll(r'\times', ' times ');
    spoken = spoken.replaceAll(r'\div', ' divided by ');
    spoken = spoken.replaceAll(r'\frac', ' ');
    spoken = spoken.replaceAll(r'\pm', ' plus or minus ');
    spoken = spoken.replaceAll(r'\cdot', ' times ');
    spoken = spoken.replaceAll('<=', ' is less than or equal to ');
    spoken = spoken.replaceAll('>=', ' is greater than or equal to ');
    spoken = spoken.replaceAll('!=', ' is not equal to ');
    spoken = spoken.replaceAll('=', ' equals ');
    spoken = spoken.replaceAll('<', ' is less than ');
    spoken = spoken.replaceAll('>', ' is greater than ');
    spoken = spoken.replaceAll('+', ' plus ');
    spoken = spoken.replaceAll('*', ' times ');
    spoken = spoken.replaceAll('/', ' divided by ');
    
    // Handle negative signs at the start
    if (spoken.trim().startsWith('-')) {
      spoken = 'negative ' + spoken.substring(1);
    }
    
    // Replace minus signs in the middle
    spoken = spoken.replaceAll(' - ', ' minus ');
    
    // Clean up extra spaces
    spoken = spoken.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return spoken;
  }

  /// The prompt we send to GPT-4o
  /// This is super important - it tells the AI exactly how to format the response
  /// We want JSON blocks with proper LaTeX formatting for equations
  String _structuredPrompt() {
    return '''
        You are a friendly tutor for a middle school student.
        The problem is clearly visible in the image. Your primary goal is to teach, not just give the answer. 
        DO NOT give the final answer first. 
        Instead, break the solution into 3 to 5 clear, simple, and logical steps. 
        For each step, explain the *why* in a simple way and ask a brief, guiding question 
        at the end of the explanation, like 'Can you see why we need to do this first?' or 'What do you think is the next logical step?' 
        Keep the language highly engaging for a middle schooler.
        Solve the math problem shown in the image.


        CRITICAL OUTPUT RULES:
        - Return ONLY valid JSON.
        - Do NOT include markdown symbols (*, **, _, #).
        - Do NOT wrap the response in code fences.
        - Do NOT include explanations outside the JSON.
        - Do NOT split sentences across multiple lines.

        IMPORTANT FOR EQUATIONS:
        - ALL equations must be in LaTeX format.
        - Escape all backslashes for JSON (use \\\\ instead of \\).
        - Use proper LaTeX symbols: \\\\leq for ≤, \\\\geq for ≥, \\\\times for ×, \\\\div for ÷.
        - Example: "-2(x + 6) \\\\leq 8" or "-2x - 12 \\\\leq 8"

        Return a JSON array of objects.
        Each object must have:
        - type: one of "header", "paragraph", "equation", "question"
        - text: a complete sentence or equation (in LaTeX for equations)

        STRUCTURE GUIDELINES:
        - Start with a "header" called "Solution".
        - Use 3–6 logical steps.
        - Each step should include:
          - a header describing the step
          - a paragraph explaining WHY and WHAT we're doing
          - an equation in LaTeX format showing the mathematical work
          - a guiding question to engage the student

        EXAMPLE OUTPUT:
        [
          {"type":"header","text":"Solution"},
          {"type":"header","text":"Step 1: Distribute the -2"},
          {"type":"paragraph","text":"The equation starts with -2(x + 6) \\\\leq 8. First, distribute the -2 across the terms inside the parentheses."},
          {"type":"equation","text":"-2(x + 6) \\\\leq 8"},
          {"type":"equation","text":"-2x - 12 \\\\leq 8"},
          {"type":"question","text":"What do you get when you distribute -2 inside the parentheses?"},
          {"type":"header","text":"Step 2: Add 12 to Both Sides"},
          {"type":"paragraph","text":"To isolate the -2x on one side, add 12 to both sides of the inequality."},
          {"type":"equation","text":"-2x - 12 + 12 \\\\leq 8 + 12"},
          {"type":"equation","text":"-2x \\\\leq 20"}
        ]
        ''';
  }

  /// Cleans up the response from GPT - sometimes it adds markdown code fences
  /// even when we tell it not to, so we strip those out
  String _stripCodeFences(String input) {
    if (input.isEmpty) return input;

    // Remove ```json or ``` code fences at the start and end
    String s = input
        .replaceAll(RegExp(r'^\s*```(?:json)?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```\s*$', multiLine: true), '')
        .trim();

    // Remove common prefixes like "Answer:" or "Response:"
    s = s.replaceAll(
      RegExp(r'^(Answer|Response|Output)\s*:\s*', caseSensitive: false),
      '',
    );

    return s.trim();
  }

  /// Tries to parse the JSON response with some fallback logic
  /// Sometimes the AI includes extra text, so we try to extract just the JSON array
  List<SolutionBlock> _parseStructuredResponse(String raw) {
    // First attempt: try to decode the whole thing as JSON
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return _mapToBlocks(decoded);
      }
    } catch (_) {
      // If that fails, continue to fallback
    }

    // Second attempt: look for the JSON array specifically
    // Find the first [ and last ] and try to parse just that
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      final candidate = raw.substring(start, end + 1);
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is List) {
          return _mapToBlocks(decoded);
        }
      } catch (_) {
        // Still failed, continue to error handling
      }
    }

    // If all parsing attempts failed, show a helpful error with a preview
    final preview = raw.length > 800
        ? raw.substring(0, 800) + '... (truncated)'
        : raw;

    throw Exception(
      'Model returned invalid JSON.\nPreview:\n$preview',
    );
  }

  /// Converts the raw JSON list into our SolutionBlock objects
  /// Filters out any empty blocks too
  List<SolutionBlock> _mapToBlocks(List<dynamic> decoded) {
    return decoded
        .whereType<Map<String, dynamic>>() // Only keep valid maps
        .map((e) => SolutionBlock.fromJson(e)) // Convert to SolutionBlock
        .where((b) => b.text.isNotEmpty) // Skip empty blocks
        .toList();
  }
}
