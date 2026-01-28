import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../constants/api.dart';

/// A single structured block returned by the model
class SolutionBlock {
  final String type; // header | paragraph | equation | question
  final String text;

  SolutionBlock({required this.type, required this.text});

  factory SolutionBlock.fromJson(Map<String, dynamic> json) {
    return SolutionBlock(
      type: (json['type'] ?? 'paragraph').toString(),
      text: (json['text'] ?? '').toString().trim(),
    );
  }
}

class OpenAIService {
  /// Analyzes a math problem image and returns structured solution blocks.
  Future<List<SolutionBlock>> analyzeMathProblem(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $OPENAI_API_KEY',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
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

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error']?['message'] ?? 'Failed to analyze problem',
        );
      }

      final data = jsonDecode(response.body);
      String rawContent = data['choices'][0]['message']['content'] ?? '';

      rawContent = _stripCodeFences(rawContent);

      return _parseStructuredResponse(rawContent);
    } catch (e) {
      throw Exception('Error analyzing math problem: $e');
    }
  }

  /// Strongly constrained prompt forcing clean JSON and safe equations
  String _structuredPrompt() {
    return '''
You are a friendly, patient middle school math tutor.

Solve the math problem shown in the image.

CRITICAL OUTPUT RULES:
- Return ONLY valid JSON.
- Do NOT include markdown symbols (*, **, _, #).
- Do NOT wrap the response in code fences.
- Do NOT include explanations outside the JSON.
- Do NOT split sentences across multiple lines.

IMPORTANT FOR EQUATIONS:
- You may write equations in plain text.
- If you include LaTeX (such as \\int, \\frac), escape all backslashes for JSON.
- You may avoid LaTeX entirely if needed.

Return a JSON array of objects.
Each object must have:
- type: one of "header", "paragraph", "equation", "question"
- text: a complete sentence or equation

STRUCTURE GUIDELINES:
- Start with a "header" called "Solution".
- Use 3–6 logical steps.
- Each step should include:
  - a header
  - a paragraph explaining WHY
  - an equation if applicable
  - a guiding question

EXAMPLE OUTPUT:
[
  {"type":"header","text":"Step 1: Choose u and dv"},
  {"type":"paragraph","text":"We choose u to simplify when differentiated and dv to be easy to integrate."},
  {"type":"equation","text":"Let u = x and dv = e^x dx"},
  {"type":"question","text":"Why is this a good choice for u?"}
]
''';
  }

  /// Removes ```json fences and common wrappers
  String _stripCodeFences(String input) {
    if (input.isEmpty) return input;

    String s = input
        .replaceAll(RegExp(r'^\s*```(?:json)?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```\s*$', multiLine: true), '')
        .trim();

    s = s.replaceAll(
      RegExp(r'^(Answer|Response|Output)\s*:\s*', caseSensitive: false),
      '',
    );

    return s.trim();
  }

  /// Safely parses structured JSON with fallbacks
  List<SolutionBlock> _parseStructuredResponse(String raw) {
    // Attempt 1: direct decode
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return _mapToBlocks(decoded);
      }
    } catch (_) {}

    // Attempt 2: extract array substring
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      final candidate = raw.substring(start, end + 1);
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is List) {
          return _mapToBlocks(decoded);
        }
      } catch (_) {}
    }

    // Final failure: readable debug preview
    final preview = raw.length > 800
        ? raw.substring(0, 800) + '... (truncated)'
        : raw;

    throw Exception(
      'Model returned invalid JSON.\nPreview:\n$preview',
    );
  }

  /// Converts decoded JSON list into SolutionBlocks safely
  List<SolutionBlock> _mapToBlocks(List<dynamic> decoded) {
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => SolutionBlock.fromJson(e))
        .where((b) => b.text.isNotEmpty)
        .toList();
  }
}
