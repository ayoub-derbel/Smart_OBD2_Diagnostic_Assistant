import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/entities/diagnostic_result.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'rag_api_client.dart';

class AiChatResult {
  final String? text;

  AiChatResult({this.text});
}

class AiApiService {
  final Dio _dio = Dio();
  final RagApiClient _ragClient = RagApiClient();

  Future<bool> _useRagBackend() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();
      if (remoteConfig.getBool('use_rag_backend')) return true;
      return remoteConfig.getString('use_rag_backend').toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  static const String _basePrompt = """
You are Smart OBD AI, an automotive diagnostic assistant.
Answer only vehicle/OBD/repair/safety questions; refuse off-topic briefly.
Use only provided scan data/history; never invent missing values.
Separate facts, likely causes, and checks. Mention evidence when useful.
Safety first for misfire, overheating, brake, smoke, fuel smell, power loss.
Reply in the user's language.
""";

  static const String _diagnosticPrompt = """
Mode: DIAGNOSTIC_REPORT.
Return valid JSON only. No Markdown. No extra text.
Analyze the provided OBD scan data and generate a report strictly following this JSON schema:
{"overview":{"status":"safe|caution|danger","summary":"","primary_problem":""},"problems":[{"title":"","severity":"low|medium|high|critical","description":""}],"causes":[{"cause":"","probability":"low|medium|high","evidence":""}],"repair_plan":{"urgency":"immediate|soon|routine","steps":[{"step_number":1,"action":"","type":"diagnostic_check|part_replacement|software_reset|maintenance"}],"estimated_difficulty":"easy|moderate|hard"}}
""";

  static const String _chatPrompt = """
Mode: CHAT.
Answer in 3-5 sentences. Do not repeat the full report.
Use only the active diagnostic session and chat history.
Never request or run a new OBD scan from chat. If scan data is missing, say that a diagnostic must be launched from the UI.
For costs, give cautious ranges and mention parts/labor/location variation.
""";

  Future<String> _getApiKey() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();

      final apiKey = remoteConfig.getString('groq_api_key');
      if (apiKey.isEmpty) {
        throw Exception(
          "La cle API Groq est introuvable dans Firebase Remote Config.",
        );
      }
      return apiKey;
    } catch (e) {
      throw Exception("Erreur lors de la recuperation de la cle API: $e");
    }
  }

  Future<DiagnosticResult> analyzeDtc(String dtcCode, String carInfo) async {
    final String systemPrompt = """
You are an automotive diagnostic assistant.
You need to explain OBD-II codes in a clear and reassuring way for a driver.

CONTEXT:
The user will provide a DTC code and vehicle information.
IMPORTANT: If the vehicle information provided is a 17-character string, it is a VIN (Vehicle Identification Number).
You MUST decode this VIN to identify the Make, Model, and Year of the vehicle before providing the diagnostic.

For each OBD-II code, you must provide:
- Identification: (Only if a VIN was provided) Confirm the vehicle you identified (e.g. "2020 Ford Explorer")
- An interpretation of the problem in simple terms
- The possible causes (ordered from most probable to least probable)
- Advise / troubleshooting actions for the driver. Use as many actions as are truly useful; do not force a fixed number of steps.

IMPORTANT:
- Always list causes in decreasing order of likelihood.
- Use practical, real-world probability based on common failure patterns for that specific vehicle.

Now, provide your answer strictly in the JSON format below:

{
  "identified_vehicle": "Make Model Year",
  "problem": "Simple explanation",
  "explanation": "Detailed technical but accessible explanation",
  "possible_causes": [
    "Most probable cause",
    "Less probable cause"
  ],
  "recommended_actions": [
    "Step 1",
    "Step 2"
  ]
}
""";

    final String userPrompt =
        """
DTC Code: $dtcCode
Vehicle Info (Model or VIN): $carInfo
""";

    try {
      final apiKey = await _getApiKey();

      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.7,
          'response_format': {'type': 'json_object'},
        },
      );

      if (response.statusCode == 200) {
        final responseText =
            response.data['choices'][0]['message']['content'] as String;
        return _parseResponse(responseText);
      } else {
        throw Exception('Erreur API Groq: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Erreur reseau ou API Groq: ${e.message}');
    } catch (e) {
      throw Exception('Erreur inattendue: $e');
    }
  }

  /// Prompt optimise: tronc commun court + bloc specifique au mode actif.
  Future<AiChatResult> chatWithUnifiedContext({
    required List<Map<String, dynamic>> history,
    Map<String, dynamic>? diagnosticContext,
    bool isDiagnosticReport = false,
    String scanHistoryPrompt = '',
  }) async {
    if (await _useRagBackend()) {
      try {
        return await _ragClient.diagnose(
          history: history,
          diagnosticContext: diagnosticContext,
          isDiagnosticReport: isDiagnosticReport,
          scanHistoryPrompt: scanHistoryPrompt,
        );
      } on DioException catch (e) {
        throw Exception(
          'Erreur API RAG backend: ${e.message}. Verifiez que uvicorn tourne sur le port 8080.',
        );
      } catch (e) {
        throw Exception('Erreur RAG backend: $e');
      }
    }

    final systemPrompt = _buildSystemPrompt(
      diagnosticContext: diagnosticContext,
      isDiagnosticReport: isDiagnosticReport,
      scanHistoryPrompt: scanHistoryPrompt,
    );

    try {
      final apiKey = await _getApiKey();
      final preparedHistory = _prepareHistoryForRequest(history);

      final List<Map<String, dynamic>> apiMessages = [
        {'role': 'system', 'content': systemPrompt},
        ...preparedHistory,
      ];

      final Map<String, dynamic> requestBody = {
        'model': 'llama-3.3-70b-versatile',
        'messages': apiMessages,
        'temperature': isDiagnosticReport ? 0.2 : 0.6,
      };

      if (isDiagnosticReport) {
        requestBody['response_format'] = {'type': 'json_object'};
      }

      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final choice = response.data['choices'][0];
        final message = choice['message'];
        final content = message['content'] as String? ?? '';
        final cleanedContent = content
            .replaceAll(RegExp(r'<function=.*?>\<\/function\>'), '')
            .replaceAll(
              RegExp(r'<tool_call>.*?<\/tool_call>', dotAll: true),
              '',
            )
            .trim();
        return AiChatResult(text: cleanedContent);
      }
      throw Exception('Erreur API Groq: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Erreur reseau ou API Groq: ${e.message}');
    } catch (e) {
      throw Exception('Erreur inattendue: $e');
    }
  }

  String _buildSystemPrompt({
    required Map<String, dynamic>? diagnosticContext,
    required bool isDiagnosticReport,
    required String scanHistoryPrompt,
  }) {
    final scan = _compactVehicleContext(diagnosticContext);
    final history = scanHistoryPrompt.trim().isEmpty
        ? 'none'
        : scanHistoryPrompt.trim();
    final modePrompt = isDiagnosticReport ? _diagnosticPrompt : _chatPrompt;

    return """
$_basePrompt
Scan:
$scan

History:
$history

$modePrompt
""";
  }

  String _compactVehicleContext(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) return 'none';

    final parts = <String>[];
    final vin = context['vin']?.toString().trim();
    if (vin != null && vin.isNotEmpty) {
      parts.add('vin=$vin');
    }

    final stored = _asStringList(context['stored_dtcs']);
    final pending = _asStringList(context['pending_dtcs']);
    if (stored.isNotEmpty) parts.add('dtc_stored=${stored.join(",")}');
    if (pending.isNotEmpty) parts.add('dtc_pending=${pending.join(",")}');

    final freezeFrames = _compactFreezeFrames(context['freeze_frames']);
    if (freezeFrames.isNotEmpty) {
      parts.add('freeze=$freezeFrames');
    }

    final pidValues = _compactMap(context['pid_values_raw'], maxEntries: 12);
    if (pidValues.isNotEmpty) {
      parts.add('pid=$pidValues');
    }

    final supportedPids = _asStringList(context['supported_pids']);
    if (supportedPids.isNotEmpty) {
      parts.add('supported=${supportedPids.take(15).join(",")}');
    }

    return parts.isEmpty ? 'none' : parts.join('\n');
  }

  List<String> _asStringList(dynamic value) {
    if (value == null) return const [];
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final single = value.toString().trim();
    return single.isEmpty ? const [] : [single];
  }

  String _compactFreezeFrames(dynamic value) {
    if (value is! Iterable) return '';
    return value
        .take(3)
        .map((frame) => _compactMap(frame, maxEntries: 8))
        .where((frame) => frame.isNotEmpty)
        .join(' | ');
  }

  String _translatePidKey(String key) {
    switch (key.toLowerCase().trim()) {
      case '04': return 'engine_load';
      case '05': return 'coolant_temp';
      case '06': return 'short_term_fuel_trim_1';
      case '07': return 'long_term_fuel_trim_1';
      case '0c': return 'engine_rpm';
      case '0d': return 'vehicle_speed';
      case '0e': return 'timing_advance';
      case '0f': return 'intake_air_temp';
      case '10': return 'maf_flow';
      case '11': return 'throttle_position';
      default: return key;
    }
  }

  String _compactMap(dynamic value, {int maxEntries = 10}) {
    if (value is Map) {
      return value.entries
          .take(maxEntries)
          .map((entry) => '${_translatePidKey(entry.key.toString())}=${entry.value}')
          .join(' ');
    }
    if (value is Iterable) {
      return value.take(maxEntries).map((item) => item.toString()).join(' ');
    }
    return value?.toString() ?? '';
  }

  List<Map<String, dynamic>> _prepareHistoryForRequest(
    List<Map<String, dynamic>> history,
  ) {
    final prepared = <Map<String, dynamic>>[];

    for (final original in history) {
      final role = original['role'];
      if (role == 'tool') continue;
      if (role == 'assistant' && original['tool_calls'] != null) continue;

      final content = original['content'];
      if (role == 'assistant' && content is String) {
        final summary = _summarizeDiagnosticReport(content);
        if (summary != null) {
          prepared.add({'role': 'assistant', 'content': summary});
          continue;
        }
      }

      prepared.add(Map<String, dynamic>.from(original));
    }

    return prepared;
  }

  String? _summarizeDiagnosticReport(String content) {
    final jsonReport = _tryDecodeJsonMap(content);
    if (jsonReport != null && _looksLikeDiagnosticJson(jsonReport)) {
      String safety = '';
      String issue = '';
      String urgency = '';
      
      final overview = jsonReport['overview'];
      if (overview is Map) {
        safety = overview['status']?.toString() ?? '';
        issue = overview['primary_problem']?.toString() ?? '';
      } else {
        safety = _firstString(jsonReport, ['safety', 'safety_status']);
        issue = _firstString(jsonReport, ['issue', 'main_issue']);
      }
      
      final repairPlan = jsonReport['repair_plan'];
      if (repairPlan is Map) {
        urgency = repairPlan['urgency']?.toString() ?? '';
      } else {
        urgency = _firstString(jsonReport, ['urgency']);
      }

      final causes = _extractCauseNames(
        jsonReport['causes'] ?? jsonReport['probable_causes'],
      );
      return [
        'Last report:',
        if (safety.isNotEmpty) 'safety=$safety;',
        if (issue.isNotEmpty) 'issue=$issue;',
        if (urgency.isNotEmpty) 'urgency=$urgency;',
        if (causes.isNotEmpty) 'causes=${causes.take(3).join(",")};',
      ].join(' ');
    }

    final normalized = content.toUpperCase();
    final isFivePointReport =
        normalized.contains('SAFETY') &&
        normalized.contains('ISSUE') &&
        (normalized.contains('REPAIR') || normalized.contains('URGENCY'));
    if (!isFivePointReport) return null;

    final safety = _extractReportField(content, r'SAFETY\s*:\s*(.*?)(?=\n|$)');
    final issue = _extractReportField(content, r'ISSUE\s*:\s*(.*?)(?=\n|$)');
    final urgency = _extractReportField(
      content,
      r'URGENCY\s*:\s*(.*?)(?=\n|$)',
    );
    return [
      'Last report:',
      if (safety.isNotEmpty) 'safety=$safety;',
      if (issue.isNotEmpty) 'issue=$issue;',
      if (urgency.isNotEmpty) 'urgency=$urgency;',
    ].join(' ');
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String content) {
    try {
      var jsonText = content.trim();
      if (jsonText.contains('```json')) {
        final start = jsonText.indexOf('```json') + 7;
        final end = jsonText.lastIndexOf('```');
        if (end > start) jsonText = jsonText.substring(start, end).trim();
      } else if (jsonText.contains('{')) {
        final start = jsonText.indexOf('{');
        final end = jsonText.lastIndexOf('}');
        if (end > start) jsonText = jsonText.substring(start, end + 1).trim();
      }

      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _looksLikeDiagnosticJson(Map<String, dynamic> json) {
    return json.containsKey('overview') ||
        json.containsKey('repair_plan') ||
        json.containsKey('safety') ||
        json.containsKey('safety_status') ||
        json.containsKey('dtcs') ||
        json.containsKey('detected_dtcs') ||
        json.containsKey('causes') ||
        json.containsKey('probable_causes');
  }

  String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  List<String> _extractCauseNames(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) {
          if (item is Map) {
            return (item['cause'] ??
                    item['title'] ??
                    item['probable_cause'] ??
                    '')
                .toString()
                .trim();
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _extractReportField(String text, String pattern) {
    final match = RegExp(
      pattern,
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    return match?.group(1)?.replaceAll('**', '').replaceAll('*', '').trim() ??
        '';
  }

  DiagnosticResult _parseResponse(String responseText) {
    try {
      String jsonStr = responseText;

      if (responseText.contains('```json')) {
        final start = responseText.indexOf('```json') + 7;
        final end = responseText.lastIndexOf('```');
        if (start != -1 && end != -1 && end > start) {
          jsonStr = responseText.substring(start, end).trim();
        }
      } else if (responseText.contains('{')) {
        final start = responseText.indexOf('{');
        final end = responseText.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          jsonStr = responseText.substring(start, end + 1).trim();
        }
      }

      final Map<String, dynamic> jsonData = jsonDecode(jsonStr);

      final vehicle = jsonData['identified_vehicle']?.toString();
      final problem = jsonData['problem']?.toString() ?? '';
      final explanation = jsonData['explanation']?.toString() ?? '';

      String interpretation = '';
      if (problem.isNotEmpty && explanation.isNotEmpty) {
        interpretation = '$problem\n\n$explanation';
      } else {
        interpretation = problem.isNotEmpty ? problem : explanation;
      }

      final possibleCausesList =
          jsonData['possible_causes'] as List<dynamic>? ?? [];
      final causesStr = possibleCausesList
          .map((e) => "- ${e.toString()}")
          .join("\n");

      final actionsList =
          jsonData['recommended_actions'] as List<dynamic>? ?? [];
      final actionsStr = actionsList.map((e) => "- ${e.toString()}").join("\n");

      return DiagnosticResult(
        identifiedVehicle: vehicle,
        interpretation: interpretation.isEmpty
            ? "Interpretation non trouvee dans la reponse."
            : interpretation,
        possibleCauses: causesStr.isEmpty ? "Causes non trouvees." : causesStr,
        troubleshootingSteps: actionsStr.isEmpty
            ? "Actions non trouvees."
            : actionsStr,
      );
    } catch (e) {
      return DiagnosticResult(
        interpretation:
            "Erreur de formatage de l'IA.\n\nContenu brut:\n$responseText",
        possibleCauses: "Erreur de formatage",
        troubleshootingSteps: "Erreur de formatage",
      );
    }
  }
}
