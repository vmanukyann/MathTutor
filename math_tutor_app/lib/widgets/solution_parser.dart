import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../constants/colors.dart';

class SolutionParser {
  /// Helper: remove triple backticks and surrounding markdown fences
  static String _stripCodeFence(String s) {
    final codeFence = RegExp(r'```(?:latex)?\s*([\s\S]*?)\s*```', caseSensitive: false);
    if (codeFence.hasMatch(s)) {
      return s.replaceAllMapped(codeFence, (m) => m.group(1) ?? '');
    }
    return s;
  }

  /// Parses a block of text into segments of plain text and LaTeX.
  static List<Widget> _parseSolutionIntoWidgets(String content) {
    content = _stripCodeFence(content);

    final latexRegex = RegExp(
      r'(\$\$[\s\S]*?\$\$|\$[\s\S]*?\$|\\\[[\s\S]*?\\\]|\\\([\s\S]*?\\\))',
      multiLine: true,
    );

    final matches = latexRegex.allMatches(content).toList();

    if (matches.isEmpty) {
      final lines = content.split('\n');
      return lines.where((l) => l.trim().isNotEmpty).map((line) {
        final looksLikeTex = RegExp(r'\\(frac|int|sum|sin|cos|sqrt|begin|end|cdot)|\^|_\{').hasMatch(line);
        if (looksLikeTex) {
          final tex = line.trim();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: Math.tex(
              tex,
              textStyle: const TextStyle(fontSize: 18, color: AppColors.textWhite),
              mathStyle: MathStyle.display,
            ),
          );
        } else {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: SelectableText(
              line.trim(),
              style: const TextStyle(color: AppColors.textWhite, fontSize: 15, height: 1.6),
            ),
          );
        }
      }).toList();
    }

    final widgets = <Widget>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        final plain = content.substring(lastEnd, match.start).trim();
        if (plain.isNotEmpty) {
          final paragraphs = plain.split('\n').where((p) => p.trim().isNotEmpty);
          for (final p in paragraphs) {
            widgets.add(Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: SelectableText(
                p.trim(),
                style: const TextStyle(color: AppColors.textWhite, fontSize: 15, height: 1.6),
              ),
            ));
          }
        }
      }

      final rawLatex = match.group(0) ?? '';
      String latexInner = rawLatex;

      if (latexInner.startsWith(r'$$') && latexInner.endsWith(r'$$')) {
        latexInner = latexInner.substring(2, latexInner.length - 2);
      } else if (latexInner.startsWith(r'$') && latexInner.endsWith(r'$')) {
        latexInner = latexInner.substring(1, latexInner.length - 1);
      } else if (latexInner.startsWith(r'\[') && latexInner.endsWith(r'\]')) {
        latexInner = latexInner.substring(2, latexInner.length - 2);
      } else if (latexInner.startsWith(r'\(') && latexInner.endsWith(r'\)')) {
        latexInner = latexInner.substring(2, latexInner.length - 2);
      }

      latexInner = latexInner.trim();

      if (latexInner.isNotEmpty) {
        widgets.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: Math.tex(
            latexInner,
            textStyle: const TextStyle(fontSize: 18, color: AppColors.textWhite),
            mathStyle: MathStyle.display,
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      final trailing = content.substring(lastEnd).trim();
      if (trailing.isNotEmpty) {
        final paragraphs = trailing.split('\n').where((p) => p.trim().isNotEmpty);
        for (final p in paragraphs) {
          widgets.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: SelectableText(
              p.trim(),
              style: const TextStyle(color: AppColors.textWhite, fontSize: 15, height: 1.6),
            ),
          ));
        }
      }
    }

    return widgets;
  }

  static Widget buildFormattedSolution(String solution) {
    final widgets = _parseSolutionIntoWidgets(solution);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lightbulb, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Solution',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...widgets,
      ],
    );
  }
}