import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../constants/api.dart';

/// Represents a single block of content in the solution.
/// Can be a header, paragraph, equation, or question.
class SolutionBlock {
  final String type; // header | paragraph | equation | question
  final String text;

  SolutionBlock({required this.type, required this.text});

  // Creates a SolutionBlock from JSON response.
  factory SolutionBlock.fromJson(Map<String, dynamic> json) {
    return SolutionBlock(
      type: (json['type'] ?? 'paragraph').toString(),
      text: (json['text'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text};
  }
}

/// Structured result from problem analysis.
class ProblemAnalysis {
  final List<SolutionBlock> solution;
  final String skillCategory;
  final String skillName;

  const ProblemAnalysis({
    required this.solution,
    required this.skillCategory,
    required this.skillName,
  });
}

class OpenAIService {
  /// Main function that takes an image path and sends it for analysis.
  /// Returns solution blocks plus inferred skill metadata.
  Future<ProblemAnalysis> analyzeMathProblem(String imagePath) async {
    try {
      // Read the image file and convert it to base64.
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Make the API call to OpenAI.
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
                {'type': 'text', 'text': _structuredPrompt()},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                },
              ],
            },
          ],
          'max_completion_tokens': 3000,
        }),
      );

      // Check if the request was successful.
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error']?['message'] ?? 'Failed to analyze problem',
        );
      }

      // Extract the response content.
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final messageContent =
          (data['choices'] as List<dynamic>).first['message']['content'];

      String rawContent = '';
      if (messageContent is String) {
        rawContent = messageContent;
      } else if (messageContent is List) {
        rawContent = messageContent
            .whereType<Map<String, dynamic>>()
            .map((part) => (part['text'] ?? '').toString())
            .join('\n');
      }

      // Clean up any code fences or extra formatting.
      rawContent = _stripCodeFences(rawContent);

      // Parse the JSON response into structured solution + skill metadata.
      return _parseStructuredResponse(rawContent);
    } catch (e) {
      throw Exception('Error analyzing math problem: $e');
    }
  }

  /// Generates audio explanation of the solution using OpenAI TTS.
  /// Returns the path to the saved audio file.
  Future<String> generateAudioExplanation(List<SolutionBlock> solution) async {
    try {
      // Convert the solution blocks into a natural, kid-friendly explanation.
      final explanationText = _convertSolutionToSpeech(solution);

      // Make the API call to OpenAI TTS.
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $OPENAI_API_KEY',
        },
        body: jsonEncode({
          'model':
              'tts-1', // Use tts-1 for faster generation, tts-1-hd for higher quality.
          'input': explanationText,
          'voice': 'nova', // Friendly voice good for educational narration.
          'speed': 0.9, // Slightly slower for better comprehension.
        }),
      );

      // Check if the request was successful.
      if (response.statusCode != 200) {
        final errorData = response.body;
        throw Exception('Failed to generate audio: $errorData');
      }

      // Save the audio file to a temporary location.
      final tempDir = Directory.systemTemp;
      final audioFile = File(
        '${tempDir.path}/math_explanation_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await audioFile.writeAsBytes(response.bodyBytes);

      return audioFile.path;
    } catch (e) {
      throw Exception('Error generating audio: $e');
    }
  }

  /// Converts solution blocks into natural speech text.
  /// Removes LaTeX and makes it conversational for a student.
  String _convertSolutionToSpeech(List<SolutionBlock> solution) {
    final buffer = StringBuffer();

    buffer.writeln(
      "Hi there! Let me walk you through this problem step by step.",
    );
    buffer.writeln(); // Short pause.

    for (var block in solution) {
      switch (block.type) {
        case 'header':
          // Skip the main "Solution" header, but announce step headers.
          if (!block.text.toLowerCase().contains('solution')) {
            buffer.writeln(block.text);
            buffer.writeln(); // Pause after header.
          }
          break;

        case 'paragraph':
          // Add the explanation text as-is.
          buffer.writeln(block.text);
          break;

        case 'equation':
          // Convert LaTeX to spoken math.
          final spokenEquation = _convertLatexToSpeech(block.text);
          buffer.writeln(spokenEquation);
          break;

        case 'question':
          // Add slight emphasis to questions.
          buffer.writeln(block.text);
          buffer.writeln(); // Pause after question.
          break;
      }
    }

    buffer.writeln("And that's how we solve it! Do you have any questions?");

    return buffer.toString();
  }

  /// Converts LaTeX equations to speakable text.
  /// Example: "-2x \\leq 8" -> "negative 2 x is less than or equal to 8".
  String _convertLatexToSpeech(String latex) {
    String spoken = latex;

    // Remove LaTeX escapes.
    spoken = spoken.replaceAll(r'\\', r'\');

    // Replace common math symbols.
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

    // Handle negative signs at the start.
    if (spoken.trim().startsWith('-')) {
      spoken = 'negative ${spoken.substring(1)}';
    }

    // Replace minus signs in the middle.
    spoken = spoken.replaceAll(' - ', ' minus ');

    // Clean up extra spaces.
    spoken = spoken.replaceAll(RegExp(r'\s+'), ' ').trim();

    return spoken;
  }

  /// Prompt for structured tutor output + skill classification.
  String _structuredPrompt() {
    return '''
        You are a friendly tutor for a middle school student.
        The problem is clearly visible in the image. Your primary goal is to teach, not just give the answer.
        DO NOT give the final answer first.
        Instead, break the solution into 3 to 5 clear, simple, and logical steps.
        For each step, explain the why in a simple way and ask a brief guiding question.
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
        - Escape all backslashes for JSON.
        - Use proper LaTeX symbols like \\leq, \\geq, \\times, and \\div.

        Return a JSON object with EXACTLY these top-level keys:
        - "skill_category": one of [Arithmetic, Algebra, Geometry, Statistics, Trigonometry, Calculus, Functions, Other]
        - "skill_name": short specific skill label (example: "Solving Linear Inequalities")
        - "solution": JSON array of objects

        Each object inside "solution" must have:
        - "type": one of "header", "paragraph", "equation", "question"
        - "text": a complete sentence or equation (in LaTeX for equations)

        STRUCTURE GUIDELINES:
        - Start with a "header" called "Solution".
        - Use 3-6 logical steps.
        - Each step should include:
          - a header describing the step
          - a paragraph explaining WHY and WHAT we're doing
          - an equation in LaTeX format showing the mathematical work
          - a guiding question to engage the student

        EXAMPLE OUTPUT:
        {
          "skill_category":"Algebra",
          "skill_name":"Solving Linear Inequalities",
          "solution":[
            {"type":"header","text":"Solution"},
            {"type":"header","text":"Step 1: Distribute the -2"},
            {"type":"paragraph","text":"The equation starts with -2(x + 6) \\leq 8. First, distribute the -2 across the terms inside the parentheses."},
            {"type":"equation","text":"-2(x + 6) \\leq 8"},
            {"type":"equation","text":"-2x - 12 \\leq 8"},
            {"type":"question","text":"What do you get when you distribute -2 inside the parentheses?"}
          ]
        }
        ''';
  }

  /// Cleans up response text from the model.
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

  /// Parse model response with fallback support for object/array formats.
  ProblemAnalysis _parseStructuredResponse(String raw) {
    ProblemAnalysis? parsed;

    // First attempt: decode whole payload.
    try {
      final decoded = jsonDecode(raw);
      parsed = _parseDecodedResponse(decoded);
      if (parsed != null) return parsed;
    } catch (_) {
      // Continue to fallback parsing.
    }

    // Second attempt: extract JSON object.
    final objectStart = raw.indexOf('{');
    final objectEnd = raw.lastIndexOf('}');
    if (objectStart != -1 && objectEnd != -1 && objectEnd > objectStart) {
      final candidate = raw.substring(objectStart, objectEnd + 1);
      try {
        final decoded = jsonDecode(candidate);
        parsed = _parseDecodedResponse(decoded);
        if (parsed != null) return parsed;
      } catch (_) {
        // Continue to array fallback.
      }
    }

    // Third attempt: extract JSON array (legacy format).
    final arrayStart = raw.indexOf('[');
    final arrayEnd = raw.lastIndexOf(']');
    if (arrayStart != -1 && arrayEnd != -1 && arrayEnd > arrayStart) {
      final candidate = raw.substring(arrayStart, arrayEnd + 1);
      try {
        final decoded = jsonDecode(candidate);
        parsed = _parseDecodedResponse(decoded);
        if (parsed != null) return parsed;
      } catch (_) {
        // Fall through to error.
      }
    }

    final preview = raw.length > 800
        ? '${raw.substring(0, 800)}... (truncated)'
        : raw;

    throw Exception('Model returned invalid JSON.\nPreview:\n$preview');
  }

  ProblemAnalysis? _parseDecodedResponse(dynamic decoded) {
    if (decoded is List) {
      final blocks = _mapToBlocks(decoded);
      if (blocks.isEmpty) return null;
      return _withFallbackSkill(blocks, null, null);
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final solutionRaw =
          map['solution'] ?? map['steps'] ?? map['blocks'] ?? map['data'];
      if (solutionRaw is! List) return null;

      final blocks = _mapToBlocks(solutionRaw);
      if (blocks.isEmpty) return null;

      final category =
          map['skill_category']?.toString() ?? map['skillCategory']?.toString();
      final name =
          map['skill_name']?.toString() ?? map['skillName']?.toString();

      return _withFallbackSkill(blocks, category, name);
    }

    return null;
  }

  ProblemAnalysis _withFallbackSkill(
    List<SolutionBlock> solution,
    String? skillCategory,
    String? skillName,
  ) {
    final inferred = _inferSkill(solution);
    return ProblemAnalysis(
      solution: solution,
      skillCategory: _cleanSkillValue(skillCategory, inferred['category']!),
      skillName: _cleanSkillValue(skillName, inferred['name']!),
    );
  }

  String _cleanSkillValue(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return fallback;
    }
    return trimmed;
  }

  // Heuristic fallback if model omits skill fields.
  Map<String, String> _inferSkill(List<SolutionBlock> solution) {
    final text = solution.map((block) => block.text.toLowerCase()).join(' ');

    bool has(String pattern) =>
        RegExp(pattern, caseSensitive: false).hasMatch(text);

    if (has(r'\b(sin|cos|tan|cot|sec|csc|hypotenuse|radian|degree)\b')) {
      return {
        'category': 'Trigonometry',
        'name': 'Trigonometric Relationships',
      };
    }

    if (has(r'\b(derivative|integral|limit|d/dx|antiderivative)\b')) {
      return {'category': 'Calculus', 'name': 'Derivatives and Integrals'};
    }

    if (has(
      r'\b(mean|median|mode|probability|standard deviation|data set|histogram)\b',
    )) {
      return {
        'category': 'Statistics',
        'name': 'Data Analysis and Probability',
      };
    }

    if (has(r'\b(function|f\(x\)|domain|range|input|output)\b')) {
      return {'category': 'Functions', 'name': 'Function Analysis'};
    }

    if (has(
      r'\b(area|perimeter|volume|circumference|radius|diameter|angle|triangle|polygon)\b',
    )) {
      return {'category': 'Geometry', 'name': 'Geometric Measurement'};
    }

    if (has(r'\b(percent|percentage|ratio|proportion|fraction|decimal)\b')) {
      return {
        'category': 'Arithmetic',
        'name': 'Fractions, Ratios, and Percents',
      };
    }

    if (has(r'\b(inequality|\\leq|\\geq|<=|>=)\b')) {
      return {'category': 'Algebra', 'name': 'Solving Inequalities'};
    }

    if (has(r'\b(system of equations|simultaneous equations)\b')) {
      return {'category': 'Algebra', 'name': 'Systems of Equations'};
    }

    if (has(r'\b(quadratic|factoring|factor|x\^2)\b')) {
      return {'category': 'Algebra', 'name': 'Quadratic and Factoring Skills'};
    }

    if (has(r'\b(equation|solve for|variable)\b')) {
      return {'category': 'Algebra', 'name': 'Solving Equations'};
    }

    return {'category': 'Other', 'name': 'General Problem Solving'};
  }

  /// Converts the raw JSON list into our SolutionBlock objects.
  List<SolutionBlock> _mapToBlocks(List<dynamic> decoded) {
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => SolutionBlock.fromJson(e))
        .where((b) => b.text.isNotEmpty)
        .toList();
  }
}
