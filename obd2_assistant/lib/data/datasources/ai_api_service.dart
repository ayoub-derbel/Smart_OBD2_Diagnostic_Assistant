import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/entities/diagnostic_result.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

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
