import 'package:dio/dio.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../domain/entities/rag_response.dart';
import 'ai_api_service.dart';

class RagApiClient {
  RagApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _defaultBaseUrl = 'http://10.0.2.2:8080';
  static const String _defaultApiKey = 'dev-smart-obd-key';

  Future<Map<String, String>> _loadConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();

      final baseUrl = remoteConfig.getString('rag_api_base_url').trim();
      final apiKey = remoteConfig.getString('rag_api_key').trim();

      return {
        'baseUrl': baseUrl.isEmpty ? _defaultBaseUrl : baseUrl,
        'apiKey': apiKey.isEmpty ? _defaultApiKey : apiKey,
      };
    } catch (_) {
      return {'baseUrl': _defaultBaseUrl, 'apiKey': _defaultApiKey};
    }
  }

  Future<AiChatResult> diagnose({
    required List<Map<String, dynamic>> history,
    Map<String, dynamic>? diagnosticContext,
    bool isDiagnosticReport = false,
    String scanHistoryPrompt = '',
  }) async {
    final config = await _loadConfig();
    final ctx = diagnosticContext ?? {};

    final stored = _stringList(ctx['stored_dtcs']);
    final pending = _stringList(ctx['pending_dtcs']);
    final pidValues = _pidMap(ctx['pid_values_raw']);

    final body = {
      'stored_dtcs': stored,
      'pending_dtcs': pending,
      'vin': ctx['vin']?.toString(),
      'pid_values': pidValues,
      'history': history
          .where((m) => m['role'] != 'tool')
          .map(
            (m) => {
              'role': m['role']?.toString() ?? 'user',
              'content': m['content']?.toString() ?? '',
            },
          )
          .toList(),
      'is_diagnostic_report': isDiagnosticReport,
      'scan_history_prompt': scanHistoryPrompt,
      'query': _buildQuery(stored, pending, pidValues),
    };

    final response = await _dio.post(
      '${config['baseUrl']}/v1/diagnose',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': config['apiKey'],
        },
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
      data: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur API RAG: ${response.statusCode}');
    }

    final parsed = RagDiagnoseResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
    return AiChatResult(text: parsed.text);
  }

  List<String> _stringList(dynamic value) {
    if (value is! Iterable) return const [];
    return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, String> _pidMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  String _buildQuery(
    List<String> stored,
    List<String> pending,
    Map<String, String> pids,
  ) {
    final parts = [...stored, ...pending, 'ralenti', 'STFT', 'MAF', 'admission'];
    if (pids.containsKey('06')) parts.add('STFT ${pids['06']}');
    if (pids.containsKey('10')) parts.add('MAF ${pids['10']}');
    return parts.join(' ');
  }
}
