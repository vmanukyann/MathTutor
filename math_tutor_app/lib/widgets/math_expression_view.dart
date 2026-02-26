import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders LaTeX math and falls back to a printable expression if parsing fails.
class MathExpressionView extends StatelessWidget {
  final String expression;
  final TextStyle? textStyle;
  final MathStyle mathStyle;
  final TextAlign fallbackTextAlign;

  const MathExpressionView({
    super.key,
    required this.expression,
    this.textStyle,
    this.mathStyle = MathStyle.display,
    this.fallbackTextAlign = TextAlign.center,
  });

  static String sanitizeForMathTex(String input) {
    var cleaned = input.trim();

    while (true) {
      final before = cleaned;
      if (cleaned.length >= 4 &&
          cleaned.startsWith(r'$$') &&
          cleaned.endsWith(r'$$')) {
        cleaned = cleaned.substring(2, cleaned.length - 2).trim();
      } else if (cleaned.length >= 2 &&
          cleaned.startsWith(r'$') &&
          cleaned.endsWith(r'$')) {
        cleaned = cleaned.substring(1, cleaned.length - 1).trim();
      } else if (cleaned.length >= 4 &&
          cleaned.startsWith(r'\(') &&
          cleaned.endsWith(r'\)')) {
        cleaned = cleaned.substring(2, cleaned.length - 2).trim();
      } else if (cleaned.length >= 4 &&
          cleaned.startsWith(r'\[') &&
          cleaned.endsWith(r'\]')) {
        cleaned = cleaned.substring(2, cleaned.length - 2).trim();
      }
      if (cleaned == before) break;
    }

    cleaned = cleaned.replaceAll('\u2212', '-');
    cleaned = cleaned.replaceAll(r'\left', '');
    cleaned = cleaned.replaceAll(r'\right', '');
    cleaned = cleaned.replaceAll(RegExp(r'\\begin\{[^}]+\}'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\\end\{[^}]+\}'), '');
    cleaned = cleaned.replaceAll('&', ' ');
    cleaned = cleaned.replaceAll(r'\cr', ' ');
    cleaned = cleaned.replaceAll(r'\\', ' ');
    cleaned = cleaned.replaceAll('<=', r'\leq ');
    cleaned = cleaned.replaceAll('>=', r'\geq ');
    cleaned = cleaned.replaceAll('!=', r'\neq ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  static String toPrintableMath(String input) {
    var printable = sanitizeForMathTex(input);
    printable = printable.replaceAll(r'\leq', '<=');
    printable = printable.replaceAll(r'\geq', '>=');
    printable = printable.replaceAll(r'\neq', '!=');
    printable = printable.replaceAll(r'\times', '*');
    printable = printable.replaceAll(r'\cdot', '*');
    printable = printable.replaceAll(r'\div', '/');
    printable = printable.replaceAll(r'\pm', '+/-');

    printable = printable.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (m) => '(${m.group(1)})/(${m.group(2)})',
    );
    printable = printable.replaceAllMapped(
      RegExp(r'\\sqrt\s*\{([^{}]+)\}'),
      (m) => 'sqrt(${m.group(1)})',
    );

    printable = printable.replaceAllMapped(
      RegExp(r'\\([a-zA-Z]+)'),
      (m) => m.group(1) ?? '',
    );
    printable = printable.replaceAll('{', '(');
    printable = printable.replaceAll('}', ')');
    printable = printable.replaceAll(RegExp(r'\s+'), ' ').trim();

    return printable;
  }

  @override
  Widget build(BuildContext context) {
    final sanitized = sanitizeForMathTex(expression);
    final baseStyle =
        textStyle ??
        DefaultTextStyle.of(
          context,
        ).style.copyWith(fontSize: 18, color: Colors.white);

    if (sanitized.isEmpty) {
      return Text('', style: baseStyle);
    }

    return Math.tex(
      sanitized,
      mathStyle: mathStyle,
      textStyle: baseStyle,
      onErrorFallback: (_) => SelectableText(
        toPrintableMath(expression),
        textAlign: fallbackTextAlign,
        style: baseStyle.copyWith(height: 1.4),
      ),
    );
  }
}
