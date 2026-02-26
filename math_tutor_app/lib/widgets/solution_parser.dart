import 'package:flutter/material.dart';
import '../services/openai_service.dart';
import 'math_expression_view.dart';

/// Utility class for parsing and rendering solution blocks
/// Takes the structured blocks from OpenAI and converts them into Flutter widgets
class SolutionParser {
  /// Main function that takes a SolutionBlock and returns the appropriate widget
  static Widget buildSolutionBlock(SolutionBlock block) {
    switch (block.type) {
      case 'header':
        // Step headers or section titles
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            block.text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );

      case 'equation':
        // Math equations rendered with LaTeX
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: MathExpressionView(
                expression: block.text,
                textStyle: const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
        );

      case 'question':
        // Interactive questions to engage the student
        // Styled differently with a blue tint and question icon
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question mark icon to make it stand out
                const Icon(
                  Icons.help_outline,
                  color: Colors.lightBlueAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Colors.lightBlueAccent,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      default: // paragraph
        // Regular explanation text
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            block.text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        );
    }
  }
}
