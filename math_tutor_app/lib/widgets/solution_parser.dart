import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../services/openai_service.dart';

class SolutionParser {
  static Widget buildSolutionBlock(SolutionBlock block) {
    switch (block.type) {
      case 'header':
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
              child: Math.tex(
                _cleanLatex(block.text),
                textStyle: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
                mathStyle: MathStyle.display,
              ),
            ),
          ),
        );

      case 'question':
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

  /// Clean and prepare LaTeX string for rendering
  static String _cleanLatex(String latex) {
    // Remove any surrounding whitespace
    String cleaned = latex.trim();
    
    // If it's already wrapped in $ or $$, remove them
    if (cleaned.startsWith(r'$$') && cleaned.endsWith(r'$$')) {
      cleaned = cleaned.substring(2, cleaned.length - 2);
    } else if (cleaned.startsWith(r'$') && cleaned.endsWith(r'$')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    
    // Replace common text representations with LaTeX
    cleaned = cleaned.replaceAll('<=', r'\leq');
    cleaned = cleaned.replaceAll('>=', r'\geq');
    cleaned = cleaned.replaceAll('!=', r'\neq');
    
    return cleaned.trim();
  }
}