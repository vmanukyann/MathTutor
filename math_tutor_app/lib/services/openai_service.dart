import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

// Must contain: const String SUPABASE_ANON_KEY = '...';
import '../constants/supabase.dart';

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

  Map<String, dynamic> toJson() => {'type': type, 'text': text};
}

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

class TutorResult {
  final ProblemAnalysis analysis;
  final String audioPath;

  TutorResult({required this.analysis, required this.audioPath});
}

class OpenAIService {
  final SupabaseClient _client = Supabase.instance.client;

  String _jwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return 'JWT not 3 parts';
    final normalized = base64Url.normalize(parts[1]);
    return utf8.decode(base64Url.decode(normalized));
  }

  Future<TutorResult> tutor(String imagePath) async {
  final imageBytes = await File(imagePath).readAsBytes();
  final base64Image = base64Encode(imageBytes);

  final session = _client.auth.currentSession;
  if (session == null || session.accessToken.isEmpty) {
    throw Exception('No auth session token found. Please log in again.');
  }

  final url = Uri.parse('$SUPABASE_URL/functions/v1/tutor');

  print('✅ USING HTTP.POST (NOT invoke)');
  print('SENDING apikey len: ${SUPABASE_ANON_KEY.length}');
  print('SENDING auth len: ${session.accessToken.length}');

  final resp = await http.post(
    url,
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'image_base64': base64Image}),
  );

  print('✅ HTTP STATUS: ${resp.statusCode}');
  print('✅ HTTP BODY (first 200): ${resp.body.substring(0, resp.body.length < 200 ? resp.body.length : 200)}');

  if (resp.statusCode != 200) {
    throw Exception('Tutor edge failed: ${resp.statusCode} ${resp.body}');
  }

  final map = jsonDecode(resp.body) as Map<String, dynamic>;

  // Parse solution blocks
  final solutionRaw = map['solution'];
  final blocks = (solutionRaw is List)
      ? solutionRaw
          .where((e) => e is Map)
          .map((e) => SolutionBlock.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((b) => b.text.isNotEmpty)
          .toList()
      : <SolutionBlock>[];

  if (blocks.isEmpty) {
    throw Exception('Tutor edge returned no solution blocks.');
  }

  final skillCategory =
      (map['skill_category'] ?? map['skillCategory'] ?? 'Other').toString();
  final skillName =
      (map['skill_name'] ?? map['skillName'] ?? 'General Problem Solving').toString();

  final analysis = ProblemAnalysis(
    solution: blocks,
    skillCategory: skillCategory,
    skillName: skillName,
  );

  final audioBytes = _extractAudioBytes(map);

  final tempDir = Directory.systemTemp;
  final audioFile = File(
    '${tempDir.path}/math_explanation_${DateTime.now().millisecondsSinceEpoch}.mp3',
  );
  await audioFile.writeAsBytes(audioBytes, flush: true);

  return TutorResult(analysis: analysis, audioPath: audioFile.path);
}

  Map<String, dynamic> _coerceToMap(dynamic data) {
    if (data == null) throw Exception('Edge function returned null.');

    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Unexpected edge response type: ${data.runtimeType}');
  }

  List<int> _extractAudioBytes(Map<String, dynamic> map) {
    final b64 = (map['audio_base64'] ?? map['audioBase64'])?.toString();
    if (b64 == null || b64.isEmpty) {
      throw Exception('No audio_base64 found in edge response.');
    }
    return base64Decode(b64);
  }
}