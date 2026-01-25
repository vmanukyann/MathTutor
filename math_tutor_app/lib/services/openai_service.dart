import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../constants/api.dart';

class OpenAIService {
  Future<String> analyzeMathProblem(String imagePath) async {
    try {
      // Read the image file
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Make API call to OpenAI
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $OPENAI_API_KEY',
        },
        body: jsonEncode({
          'model': 'gpt-5',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': '''You are a math tutor. Solve this math problem step by step. 

Format your response EXACTLY like this:

PROBLEM:
[State the problem clearly]

STEP 1: [Title]
[Explanation]
[Show work using LaTeX notation wrapped in \$ symbols]

STEP 2: [Title]
[Explanation]
[Show work using LaTeX notation wrapped in \$ symbols]

STEP 3: [Title]
[Explanation]
[Show work using LaTeX notation wrapped in \$ symbols]

FINAL ANSWER:
[The answer in LaTeX]

Use clear spacing between sections. Be thorough but concise.
IMPORTANT: Wrap all mathematical expressions in LaTeX using \$ for inline math or \$\$ for display math.
For example: \$x^2 + 5x + 6 = 0\$ or \$\$\\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}\$\$
Try to keep most sentences on the same line and do not separate math into new lines from commas and colons, keep them on the same line.'''
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
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error']['message'] ?? 'Failed to analyze problem');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
