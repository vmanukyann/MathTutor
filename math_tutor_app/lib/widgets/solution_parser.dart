import 'package:flutter/material.dart';
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              block.text,
              style: const TextStyle(
                fontSize: 18,
                fontFamily: 'monospace',
                color: Colors.white,
              ),
            ),
          ),
        );

      case 'question':
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(
            block.text,
            style: const TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.white70,
            ),
          ),
        );
      }

      String normalizeLatex(String input) {
        return input
            .replaceAll('\\\\', '\\')   // \\ → \
            .replaceAll(r'\,', r'\,')   // keep spacing commands
            .trim();
      }

      }

      default: // paragraph
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            block.text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        );
    }

