import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/entities/diagnostic_result.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class AiChatResult {
  final String? text;
  final bool wantsToScan;
  final dynamic toolCallData;

  AiChatResult({this.text, this.wantsToScan = false, this.toolCallData});
}

class AiApiService {
  final Dio _dio = Dio();

  Future<String> _getApiKey() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      // Pour le développement, on réduit le délai de rafraîchissement au minimum
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1), // À changer en prod
      ));
      await remoteConfig.fetchAndActivate();
      
      final apiKey = remoteConfig.getString('groq_api_key');
      if (apiKey.isEmpty) {
        throw Exception("La clé d'API Groq est introuvable dans Firebase Remote Config.");
      }
      return apiKey;
    } catch (e) {
      throw Exception("Erreur lors de la récupération de la clé API: $e");
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
- Advise / troubleshooting actions for the driver

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

    final String userPrompt = """
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
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userPrompt,
            }
          ],
          'temperature': 0.7,
          'response_format': {'type': 'json_object'},
        },
      );

      if (response.statusCode == 200) {
        final responseText = response.data['choices'][0]['message']['content'] as String;
        return _parseResponse(responseText);
      } else {
        throw Exception('Erreur API Groq: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Erreur réseau ou API Groq: ${e.message}');
    } catch (e) {
      throw Exception('Erreur inattendue: $e');
    }
  }

  /// Un seul prompt pour tout gérer : Diagnostic initial et conversation continue
  Future<AiChatResult> chatWithUnifiedContext({
    required List<Map<String, dynamic>> history,
    Map<String, dynamic>? diagnosticContext,
    bool isDiagnosticReport = false,
    String scanHistoryPrompt = '',
  }) async {
    final String systemPrompt = """
Expert OBD-II diagnostic system. Mission: help drivers understand issues, find root causes, get repair steps.

CRITICAL OFF-TOPIC RULE: You are ONLY allowed to answer questions related to automotive diagnostics, vehicle health, OBD-II systems, or general car repair. If the user asks an off-topic question (such as recipes, food, calories in peanut butter, sports, history, coding, or general knowledge), you MUST politely refuse to answer and redirect them back to their vehicle's health (in their language). Do not answer any part of their off-topic query.

Rules: Cite evidence (DTC+PID) for every conclusion. Translate codes to plain language (e.g. P0171 = engine running lean). Safety first. Reply in user's language. Be concise.
${isDiagnosticReport ? """
Output format:
1. SAFETY: [Safe / Caution / Do not drive]
2. ISSUE: [Plain language, 2 sentences max]
3. ROOT CAUSE: [Cause] — Evidence: [DTC+PID proof] — Ruled out: [what it's not]
4. REPAIR: →Step1 →Step2 →Step3
5. URGENCY: [Now / This week / Next service]"""
: """
Conversation mode:
CRITICAL: Do NOT use the 5-point numbered template (SAFETY, ISSUE, ROOT CAUSE, etc.). Answer the user's question naturally and conversationally in 3-4 sentences max. Base every answer on the scan data. Don't repeat the full report. If asked about costs, give realistic ranges."""}
$scanHistoryPrompt
Vehicle data: ${diagnosticContext != null ? jsonEncode(diagnosticContext) : "No data yet."}
""";

    try {
      final apiKey = await _getApiKey();
      
      // Build the list of messages sent to the model
      final List<Map<String, dynamic>> apiMessages = [
        {'role': 'system', 'content': systemPrompt},
        ...history,
      ];

      // If we are in conversation mode, adjust the messages to avoid re‑using the 5‑point report
      if (!isDiagnosticReport) {
        // Replace any previous assistant message that contains the 5‑point template
        for (int i = 0; i < apiMessages.length; i++) {
          final msg = apiMessages[i];
          if (msg['role'] == 'assistant' &&
              (msg['content'] as String?)?.contains('1. SAFETY') == true) {
            apiMessages[i] = {
              'role': 'assistant',
              'content': 'Previous diagnostic report already generated.',
            };
          }
        }
        // Add explicit reminder to force conversational style
        apiMessages.add({
          'role': 'system',
          'content': 'IMPORTANT REMINDER: You are in CONVERSATION MODE. Do NOT use the 5‑point numbered template. Answer naturally in 3‑4 sentences.',
        });
      }

      final Map<String, dynamic> requestBody = {
        'model': 'llama-3.3-70b-versatile',
        'messages': apiMessages,
        'temperature': 0.6,
      };

      // If this is a diagnostic report, prevent tool calls to avoid recursion
      if (!isDiagnosticReport) {
        requestBody['tools'] = [
          {
            'type': 'function',
            'function': {
              'name': 'run_obd_scan',
              'description': 'Exécute un scan OBD-II physique pour lire les codes d\'erreur et les capteurs. N\'utilisez cet outil QUE si l\'utilisateur demande explicitement un nouveau diagnostic, veut scanner sa voiture ou si aucune donnée de scan n\'est présente. Ne l\'utilisez pas pour répondre à des questions simples sur un diagnostic existant.',
            }
          },
        ];
      }

      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final choice = response.data['choices'][0];
        final message = choice['message'];
        if (choice['finish_reason'] == 'tool_calls' || message['tool_calls'] != null) {
          return AiChatResult(
            wantsToScan: true,
            toolCallData: message['tool_calls'],
          );
        }
        final content = message['content'] as String? ?? '';
        final cleanedContent = content
            .replaceAll(RegExp(r'<function=.*?>\<\/function\>'), '')
            .replaceAll(RegExp(r'<tool_call>.*?<\/tool_call>', dotAll: true),
                '')
            .trim();
        return AiChatResult(text: cleanedContent);
      }
      throw Exception('Erreur API Groq: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Erreur réseau ou API Groq: ${e.message}');
    } catch (e) {
      throw Exception('Erreur inattendue: $e');
    }
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

      final possibleCausesList = jsonData['possible_causes'] as List<dynamic>? ?? [];
      final causesStr = possibleCausesList.map((e) => "• ${e.toString()}").join("\n");

      final actionsList = jsonData['recommended_actions'] as List<dynamic>? ?? [];
      final actionsStr = actionsList.map((e) => "• ${e.toString()}").join("\n");

      return DiagnosticResult(
        identifiedVehicle: vehicle,
        interpretation: interpretation.isEmpty ? "Interprétation non trouvée dans la réponse." : interpretation,
        possibleCauses: causesStr.isEmpty ? "Causes non trouvées." : causesStr,
        troubleshootingSteps: actionsStr.isEmpty ? "Actions non trouvées." : actionsStr,
      );
    } catch (e) {
      return DiagnosticResult(
        interpretation: "Erreur de formatage de l'IA.\n\nContenu brut:\n$responseText",
        possibleCauses: "Erreur de formatage",
        troubleshootingSteps: "Erreur de formatage",
      );
    }
  }
}
