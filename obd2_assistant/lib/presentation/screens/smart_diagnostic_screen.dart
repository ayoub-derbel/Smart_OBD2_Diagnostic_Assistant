import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../providers/diagnostic_view_model.dart';
import '../providers/chat_view_model.dart';
import '../../domain/entities/chat_message.dart';
import 'scan_history_screen.dart';
import '../../domain/entities/full_diagnostic_report.dart';
import '../../domain/entities/scan_step.dart';
import '../../domain/entities/diagnostic_session.dart';

enum StepStatus { pending, inProgress, completed }

class SmartDiagnosticScreen extends StatefulWidget {
  final DiagnosticSession? historySession;
  final bool isHistoryMode;

  const SmartDiagnosticScreen({
    super.key,
    this.historySession,
    this.isHistoryMode = false,
  });

  @override
  State<SmartDiagnosticScreen> createState() => _SmartDiagnosticScreenState();
}

class _SmartDiagnosticScreenState extends State<SmartDiagnosticScreen> {
  final TextEditingController _chatController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _currentSheetSize = 0.12;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!widget.isHistoryMode) {
        await context.read<DiagnosticViewModel>().loadActiveSession();
      }
      if (!mounted) return;
      await context.read<ChatViewModel>().updateHistory();
    });
  }

  void _onSheetSizeChanged() {
    if (_sheetController.isAttached) {
      setState(() {
        _currentSheetSize = _sheetController.size;
      });
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    super.dispose();
  }

  void _scrollToBottom(ScrollController scrollController) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, String> _parseFivePointReport(String text) {
    final Map<String, String> result = {};

    // Helper to clean up Markdown syntax like bolding or stars
    String clean(String val) {
      return val.replaceAll('**', '').replaceAll('*', '').trim();
    }

    final safetyMatch = RegExp(
      r'(?:1\.?\s*)?(?:\*\*|)?(?:SAFETY|SÉCURITÉ|SECURITE)(?:\*\*|)?\s*:\s*(.*?)(?=\n(?:2\.?\s*)?(?:\*\*|)?(?:ISSUE|PROBLÈME|PROBLEME)(?:\*\*|)?\s*:|\n\d+\.|\Z)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    final issueMatch = RegExp(
      r'(?:2\.?\s*)?(?:\*\*|)?(?:ISSUE|PROBLÈME|PROBLEME)(?:\*\*|)?\s*:\s*(.*?)(?=\n(?:3\.?\s*)?(?:\*\*|)?(?:ROOT CAUSE|CAUSE ORIGINE|CAUSE)(?:\*\*|)?\s*:|\n\d+\.|\Z)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    final rootCauseMatch = RegExp(
      r'(?:3\.?\s*)?(?:\*\*|)?(?:ROOT CAUSE|CAUSE ORIGINE|CAUSE)(?:\*\*|)?\s*:\s*(.*?)(?=\n(?:4\.?\s*)?(?:\*\*|)?(?:REPAIR|RÉPARATION|REPARATION)(?:\*\*|)?\s*:|\n\d+\.|\Z)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    final repairMatch = RegExp(
      r'(?:4\.?\s*)?(?:\*\*|)?(?:REPAIR|RÉPARATION|REPARATION)(?:\*\*|)?\s*:\s*(.*?)(?=\n(?:5\.?\s*)?(?:\*\*|)?(?:URGENCY|URGENCE)(?:\*\*|)?\s*:|\n\d+\.|\Z)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    final urgencyMatch = RegExp(
      r'(?:5\.?\s*)?(?:\*\*|)?(?:URGENCY|URGENCE)(?:\*\*|)?\s*:\s*(.*?)(?=\Z)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (safetyMatch != null) result['SAFETY'] = clean(safetyMatch.group(1)!);
    if (issueMatch != null) result['ISSUE'] = clean(issueMatch.group(1)!);
    if (rootCauseMatch != null) {
      result['ROOT CAUSE'] = clean(rootCauseMatch.group(1)!);
    }
    if (repairMatch != null) result['REPAIR'] = clean(repairMatch.group(1)!);
    if (urgencyMatch != null) result['URGENCY'] = clean(urgencyMatch.group(1)!);

    return result;
  }

  Map<String, String> _parseReportSections(String text) {
    final jsonSections = _parseJsonReport(text);
    if (jsonSections.isNotEmpty) return jsonSections;
    return _parseFivePointReport(text);
  }

  Map<String, String> _parseJsonReport(String text) {
    final jsonReport = _tryDecodeJsonMap(text);
    if (jsonReport == null || !_looksLikeDiagnosticJson(jsonReport)) {
      return {};
    }

    final sections = <String, String>{};
    final safety = _firstString(jsonReport, ['safety', 'safety_status']);
    final vehicleSummary = _firstString(jsonReport, [
      'vehicle_summary',
      'vehicleSummary',
      'summary',
    ]);
    final issue = _firstString(jsonReport, ['issue', 'main_issue']);
    final urgency = _firstString(jsonReport, ['urgency']);
    final message = _firstString(jsonReport, ['message', 'driver_message']);

    if (safety.isNotEmpty) sections['SAFETY'] = safety;
    if (vehicleSummary.isNotEmpty) {
      sections['VEHICLE SUMMARY'] = vehicleSummary;
    } else if (issue.isNotEmpty) {
      sections['VEHICLE SUMMARY'] = issue;
    }
    if (issue.isNotEmpty) sections['ISSUE'] = issue;
    if (urgency.isNotEmpty) sections['URGENCY'] = urgency;
    if (message.isNotEmpty) sections['MESSAGE'] = message;

    final dtcs = _formatDtcs(jsonReport['dtcs'] ?? jsonReport['detected_dtcs']);
    if (dtcs.isNotEmpty) sections['DTCS'] = dtcs;

    final evidence = _formatSimpleList(jsonReport['evidence']);
    if (evidence.isNotEmpty) sections['EVIDENCE'] = evidence;

    final causes = _formatCauses(
      jsonReport['causes'] ?? jsonReport['probable_causes'],
    );
    final uncertain = _formatSimpleList(
      jsonReport['uncertain'] ?? jsonReport['ruled_out_or_uncertain'],
    );
    final rootCauseParts = [
      if (causes.isNotEmpty) causes,
      if (uncertain.isNotEmpty) 'Incertitudes:\n$uncertain',
    ];
    if (rootCauseParts.isNotEmpty) {
      sections['ROOT CAUSE'] = rootCauseParts.join('\n\n');
    }

    final actions = _formatActions(
      jsonReport['actions'] ?? jsonReport['recommended_actions'],
    );
    if (actions.isNotEmpty) sections['REPAIR'] = actions;

    return sections;
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
    return json.containsKey('safety') ||
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

  String _formatSimpleList(dynamic value) {
    if (value is! Iterable) return '';
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .map((item) => '- $item')
        .join('\n');
  }

  String _formatDtcs(dynamic value) {
    if (value is! Iterable) return '';
    return value
        .map((item) {
          if (item is Map) {
            final code = item['code']?.toString() ?? '';
            final meaning = item['meaning']?.toString() ?? '';
            final status = item['status']?.toString() ?? '';
            final severity = item['severity']?.toString() ?? '';
            return [
              if (code.isNotEmpty) code,
              if (meaning.isNotEmpty) meaning,
              if (status.isNotEmpty) 'status: $status',
              if (severity.isNotEmpty) 'severity: $severity',
            ].join(' - ');
          }
          return item.toString();
        })
        .where((item) => item.trim().isNotEmpty)
        .map((item) => '- $item')
        .join('\n');
  }

  String _formatCauses(dynamic value) {
    if (value is! Iterable) return '';
    return value
        .map((item) {
          if (item is Map) {
            final cause = item['cause']?.toString() ?? '';
            final confidence = item['confidence']?.toString() ?? '';
            final why = (item['why'] ?? item['reason'])?.toString() ?? '';
            return [
              if (cause.isNotEmpty) cause,
              if (confidence.isNotEmpty) 'confidence: $confidence',
              if (why.isNotEmpty) why,
            ].join(' - ');
          }
          return item.toString();
        })
        .where((item) => item.trim().isNotEmpty)
        .map((item) => '- $item')
        .join('\n');
  }

  String _formatActions(dynamic value) {
    if (value is! Iterable) return '';
    return value
        .map((item) {
          if (item is Map) {
            final priority = item['priority']?.toString() ?? '';
            final action = item['action']?.toString() ?? '';
            return [
              if (priority.isNotEmpty) '[$priority]',
              if (action.isNotEmpty) action,
            ].join(' ');
          }
          return item.toString();
        })
        .where((item) => item.trim().isNotEmpty)
        .map((item) => '-> $item')
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final diagnosticVM = context.watch<DiagnosticViewModel>();
    final chatVM = context.watch<ChatViewModel>();

    if (!widget.isHistoryMode && chatVM.shouldExpandChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sheetController.isAttached) {
          _sheetController.animateTo(
            1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      chatVM.consumeShouldExpandChat();
    } else if (widget.isHistoryMode && chatVM.shouldExpandChat) {
      chatVM.consumeShouldExpandChat();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.isHistoryMode
              ? "Historique des Sessions"
              : "Assistant IA Smart Diagnostic",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: widget.isHistoryMode
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primaryText,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: widget.isHistoryMode
            ? const []
            : [
                IconButton(
                  icon: const Icon(Icons.history_rounded),
                  tooltip: 'Historique des scans',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScanHistoryScreen(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Réinitialiser',
                  onPressed: () async {
                    await diagnosticVM.reset();
                    await chatVM.reset();
                  },
                ),
              ],
      ),
      body: widget.isHistoryMode
          ? _buildDiagnosticContent(diagnosticVM, chatVM)
          : Stack(
              children: [
                _buildDiagnosticContent(diagnosticVM, chatVM),
                if (diagnosticVM.hasReport) _buildChatPanel(chatVM),
              ],
            ),
    );
  }

  Widget _buildDiagnosticContent(
    DiagnosticViewModel diagnosticVM,
    ChatViewModel chatVM,
  ) {
    if (diagnosticVM.isScanning) {
      return _buildScanningState(diagnosticVM);
    }

    if (diagnosticVM.error != null) {
      return _buildErrorState(diagnosticVM, chatVM);
    }

    if (!diagnosticVM.hasReport) {
      return _buildBeforeScanState(diagnosticVM, chatVM);
    }

    return _buildReportContent(diagnosticVM, chatVM);
  }

  Widget _buildBeforeScanState(
    DiagnosticViewModel diagnosticVM,
    ChatViewModel chatVM,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.settings_suggest_rounded,
                size: 72,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Diagnostic Smart IA",
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Analysez en profondeur votre véhicule et posez toutes vos questions à notre assistant intelligent.",
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.divider),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      Icons.search_rounded,
                      "Lecture en temps réel des DTCs (codes d'erreur)",
                    ),
                    const Divider(height: 24),
                    _buildFeatureRow(
                      Icons.analytics_outlined,
                      "Analyse intelligente des capteurs moteurs",
                    ),
                    const Divider(height: 24),
                    _buildFeatureRow(
                      Icons.chat_bubble_outline_rounded,
                      "Assistant IA disponible pour poser des questions",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showSymptomDialog(context, diagnosticVM, chatVM),
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                label: Text(
                  "Lancer le Diagnostic",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  final List<Map<String, dynamic>> _stepsData = [
    {
      'title': 'Connexion OBD-II',
      'subtitle': 'Établissement de la liaison avec le boîtier ELM327...',
      'icon': Icons.bluetooth_connected_rounded,
    },
    {
      'title': 'Lecture du VIN',
      'subtitle': "Identification du numéro de série pour décoder le modèle...",
      'icon': Icons.fingerprint_rounded,
    },
    {
      'title': 'Lecture des codes défaut (DTC)',
      'subtitle': 'Scan des calculateurs (ECU) à la recherche d\'erreurs...',
      'icon': Icons.error_outline_rounded,
    },
    {
      'title': 'Lecture des capteurs (PIDs)',
      'subtitle': 'Extraction des métriques physiques du moteur en direct...',
      'icon': Icons.speed_rounded,
    },
    {
      'title': 'Analyse par Intelligence Artificielle',
      'subtitle':
          'Traitement des données et formulation des recommandations...',
      'icon': Icons.psychology_rounded,
    },
  ];

  int _getStepIndex(ScanStep? step) {
    if (step == null) return -1;
    switch (step) {
      case ScanStep.connectingObd:
        return 0;
      case ScanStep.readingVin:
        return 1;
      case ScanStep.readingDtc:
        return 2;
      case ScanStep.readingPids:
        return 3;
      case ScanStep.aiAnalysis:
        return 4;
      case ScanStep.done:
        return 5;
    }
  }

  StepStatus _getStepStatus(int stepIndex, int currentIndex) {
    if (currentIndex > stepIndex) return StepStatus.completed;
    if (currentIndex == stepIndex) return StepStatus.inProgress;
    return StepStatus.pending;
  }

  void _showSymptomDialog(
    BuildContext context,
    DiagnosticViewModel diagnosticVM,
    ChatViewModel chatVM,
  ) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.note_alt_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                "Remarques & Symptômes",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Décrivez les symptômes actuels du véhicule (bruits, perte de puissance, voyants...) pour affiner l'analyse de l'IA.",
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      "Ex: Le moteur broute à bas régime, le voyant moteur est allumé...",
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: GoogleFonts.outfit(fontSize: 14),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await diagnosticVM.runFullDiagnostic();
                if (diagnosticVM.hasReport) {
                  await chatVM.initWithContext(diagnosticVM.lastScanContext);
                }
              },
              child: Text(
                "Passer",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                final note = textController.text.trim();
                Navigator.pop(context);
                await diagnosticVM.runFullDiagnostic(
                  userNote: note.isEmpty ? null : note,
                );
                if (diagnosticVM.hasReport) {
                  await chatVM.initWithContext(diagnosticVM.lastScanContext);
                }
              },
              child: Text(
                "Lancer l'analyse",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStepItem({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required StepStatus status,
    required bool isLast,
  }) {
    Color iconBgColor;
    Color iconColor;
    Widget leadingWidget;
    TextStyle titleStyle = GoogleFonts.outfit(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    TextStyle subtitleStyle = GoogleFonts.outfit(fontSize: 13);

    switch (status) {
      case StepStatus.completed:
        iconBgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);
        leadingWidget = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, color: iconColor, size: 20),
        );
        titleStyle = titleStyle.copyWith(color: AppColors.primaryText);
        subtitleStyle = subtitleStyle.copyWith(color: AppColors.secondaryText);
        break;
      case StepStatus.inProgress:
        iconBgColor = AppColors.primary.withOpacity(0.1);
        iconColor = AppColors.primary;
        leadingWidget = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
        );
        titleStyle = titleStyle.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        );
        subtitleStyle = subtitleStyle.copyWith(
          color: AppColors.primary.withOpacity(0.8),
        );
        break;
      case StepStatus.pending:
        iconBgColor = Colors.grey.shade100;
        iconColor = Colors.grey.shade400;
        leadingWidget = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 18),
        );
        titleStyle = titleStyle.copyWith(color: Colors.grey.shade400);
        subtitleStyle = subtitleStyle.copyWith(color: Colors.grey.shade400);
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              leadingWidget,
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: status == StepStatus.completed
                        ? const Color(0xFF2E7D32)
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: 4),
                  Text(subtitle, style: subtitleStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStepIconForHeader(ScanStep? step) {
    if (step == null) return Icons.directions_car_rounded;
    switch (step) {
      case ScanStep.connectingObd:
        return Icons.bluetooth_searching_rounded;
      case ScanStep.readingVin:
        return Icons.fingerprint_rounded;
      case ScanStep.readingDtc:
        return Icons.search_rounded;
      case ScanStep.readingPids:
        return Icons.speed_rounded;
      case ScanStep.aiAnalysis:
        return Icons.psychology_rounded;
      case ScanStep.done:
        return Icons.check_circle_rounded;
    }
  }

  Widget _buildScanningState(DiagnosticViewModel diagnosticVM) {
    final currentStep = diagnosticVM.currentStep;
    final currentIndex = _getStepIndex(currentStep);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glowing outer halo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.12),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  // Spinning Outer Loader
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  // Center Icon showing active stage
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getStepIconForHeader(currentStep),
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Diagnostic guidé en cours",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Veuillez patienter pendant que nous communiquons avec votre véhicule.",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Column(
              children: List.generate(_stepsData.length, (index) {
                final stepData = _stepsData[index];
                final stepStatus = _getStepStatus(index, currentIndex);

                return _buildStepItem(
                  index: index,
                  title: stepData['title'] as String,
                  subtitle: stepData['subtitle'] as String,
                  icon: stepData['icon'] as IconData,
                  status: stepStatus,
                  isLast: index == _stepsData.length - 1,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    DiagnosticViewModel diagnosticVM,
    ChatViewModel chatVM,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 72,
            ),
            const SizedBox(height: 24),
            Text(
              "Erreur de diagnostic",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              diagnosticVM.error ?? "Une erreur inattendue est survenue.",
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton(
                onPressed: () =>
                    _showSymptomDialog(context, diagnosticVM, chatVM),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Réessayer",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  FullDiagnosticReport? _tryParseStructuredReport(String text) {
    try {
      final decoded = _tryDecodeJsonMap(text);
      if (decoded == null) return null;

      if (!decoded.containsKey('overview') &&
          !decoded.containsKey('repair_plan')) {
        return null;
      }

      final overviewMap = decoded["overview"] as Map<String, dynamic>? ?? {};
      final problemsRaw = decoded["problems"] as List<dynamic>? ?? [];
      final causesRaw = decoded["causes"] as List<dynamic>? ?? [];
      final repairPlanMap =
          decoded["repair_plan"] as Map<String, dynamic>? ?? {};
      final stepsRaw = repairPlanMap["steps"] as List<dynamic>? ?? [];

      return FullDiagnosticReport(
        overview: DiagnosticOverview(
          status: overviewMap["status"]?.toString() ?? "unknown",
          summary: overviewMap["summary"]?.toString() ?? "",
          primaryProblem:
              overviewMap["primary_problem"]?.toString() ??
              "Problème principal non spécifié",
        ),
        problems: problemsRaw.map((e) {
          final problem = e as Map<String, dynamic>;
          return DiagnosticProblem(
            title: problem["title"]?.toString() ?? "Problème",
            severity: problem["severity"]?.toString() ?? "medium",
            description: problem["description"]?.toString() ?? "",
          );
        }).toList(),
        causes: causesRaw.map((e) {
          final cause = e as Map<String, dynamic>;
          return DiagnosticCause(
            cause: cause["cause"]?.toString() ?? "Cause inconnue",
            probability: cause["probability"]?.toString() ?? "medium",
            evidence: cause["evidence"]?.toString() ?? "",
          );
        }).toList(),
        repairPlan: RepairPlan(
          urgency: repairPlanMap["urgency"]?.toString() ?? "routine",
          estimatedDifficulty:
              repairPlanMap["estimated_difficulty"]?.toString() ?? "easy",
          steps: stepsRaw.map((e) {
            final step = e as Map<String, dynamic>;
            return RepairStep(
              stepNumber:
                  int.tryParse(step["step_number"]?.toString() ?? "0") ?? 0,
              action: step["action"]?.toString() ?? "",
              type: step["type"]?.toString() ?? "maintenance",
            );
          }).toList(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildStructuredReportContent(
    DiagnosticViewModel diagnosticVM,
    ChatViewModel chatVM,
    FullDiagnosticReport report,
  ) {
    final isSafe = report.overview.status.toLowerCase() == "safe";

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isHistoryMode ? 24 : 120),
      children: [
        _buildReportHeaderCard(diagnosticVM),
        const SizedBox(height: 12),
        _buildOverviewCard(report.overview),
        if (!isSafe && report.problems.isNotEmpty)
          _buildProblemsCard(report.problems),
        if (!isSafe && report.causes.isNotEmpty)
          _buildCausesCard(report.causes),
        if (!isSafe) _buildRepairPlanCard(report.repairPlan),
        if (widget.isHistoryMode) ...[
          const SizedBox(height: 4),
          _buildChatSection(chatVM),
        ],
      ],
    );
  }

  Widget _buildOverviewCard(DiagnosticOverview overview) {
    Color cardBg;
    Color borderColor;
    Color textColor;
    IconData icon;
    String safetyTitle;

    final status = overview.status.toLowerCase();
    if (status == "danger" || status == "critical") {
      cardBg = const Color(0xFFFFEBEE);
      borderColor = AppColors.error;
      textColor = AppColors.error;
      icon = Icons.dangerous_rounded;
      safetyTitle = "DANGER - Ne pas rouler";
    } else if (status == "caution" || status == "warning") {
      cardBg = const Color(0xFFFFF3E0);
      borderColor = AppColors.accent;
      textColor = const Color(0xFFD97706);
      icon = Icons.warning_amber_rounded;
      safetyTitle = "Etat du vehicule - Vigilance requise";
    } else {
      cardBg = const Color(0xFFE8F5E9);
      borderColor = AppColors.success;
      textColor = const Color(0xFF047857);
      icon = Icons.check_circle_rounded;
      safetyTitle = "SÉCURISÉ - Véhicule sain";
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor.withOpacity(0.5), width: 1.5),
      ),
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    safetyTitle,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (overview.primaryProblem.isNotEmpty) ...[
              Text(
                overview.primaryProblem,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              overview.summary,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProblemsCard(List<DiagnosticProblem> problems) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.error, width: 5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Problèmes Détectés",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...problems.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (idx > 0) const Divider(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            p.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSeverityChip(p.severity),
                      ],
                    ),
                    if (p.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.description,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical':
        color = Colors.purple;
        break;
      case 'high':
        color = AppColors.error;
        break;
      case 'medium':
        color = AppColors.accent;
        break;
      case 'low':
      default:
        color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        severity.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCausesCard(List<DiagnosticCause> causes) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.purple, width: 5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: Colors.purple,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Causes Probables",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...causes.asMap().entries.map((entry) {
                final idx = entry.key;
                final c = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (idx > 0) const Divider(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            c.cause,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildProbabilityChip(c.probability),
                      ],
                    ),
                    if (c.evidence.isNotEmpty &&
                        c.evidence.toLowerCase() != "no evidence") ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              size: 15,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.evidence,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[700],
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProbabilityChip(String probability) {
    Color color;
    switch (probability.toLowerCase()) {
      case 'high':
        color = AppColors.error;
        break;
      case 'medium':
        color = AppColors.accent;
        break;
      case 'low':
      default:
        color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        probability.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRepairPlanCard(RepairPlan plan) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.teal, width: 5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    color: Colors.teal,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Plan de Réparation",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildInfoTag(
                    "Urgence",
                    plan.urgency,
                    _urgencyColor(plan.urgency),
                  ),
                  const SizedBox(width: 12),
                  _buildInfoTag(
                    "Difficulté",
                    plan.estimatedDifficulty,
                    _difficultyColor(plan.estimatedDifficulty),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (plan.steps.isEmpty)
                Text(
                  "Aucune étape spécifique. Un entretien classique est conseillé.",
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.secondaryText,
                  ),
                )
              else
                Column(
                  children: List.generate(plan.steps.length, (idx) {
                    final step = plan.steps[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0F2F1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                "${step.stepNumber}",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.action,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatStepType(step.type),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatStepType(String type) {
    switch (type.toLowerCase()) {
      case "diagnostic_check":
        return "Vérification de diagnostic";
      case "part_replacement":
        return "Remplacement de pièce";
      case "software_reset":
        return "Réinitialisation logicielle";
      case "maintenance":
        return "Entretien standard";
      default:
        return type;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'immediate':
        return AppColors.error;
      case 'soon':
        return AppColors.accent;
      case 'routine':
      default:
        return AppColors.success;
    }
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'hard':
        return AppColors.error;
      case 'moderate':
        return AppColors.accent;
      case 'easy':
      default:
        return AppColors.success;
    }
  }

  Widget _buildReportContent(
    DiagnosticViewModel diagnosticVM,
    ChatViewModel chatVM,
  ) {
    final reportText = diagnosticVM.reportText ?? "";

    final structuredReport = _tryParseStructuredReport(reportText);
    if (structuredReport != null) {
      return _buildStructuredReportContent(
        diagnosticVM,
        chatVM,
        structuredReport,
      );
    }

    final parsed = _parseReportSections(reportText);

    // If parsing failed to extract meaningful fields, fall back to single card
    if (parsed.isEmpty ||
        parsed['SAFETY'] == null ||
        parsed['VEHICLE SUMMARY'] == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          widget.isHistoryMode ? 24 : 120,
        ),
        children: [
          _buildReportHeaderCard(diagnosticVM),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.divider),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Rapport de Diagnostic",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reportText,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isHistoryMode) ...[
            const SizedBox(height: 4),
            _buildChatSection(chatVM),
          ],
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isHistoryMode ? 24 : 120),
      children: [
        _buildReportHeaderCard(diagnosticVM),
        const SizedBox(height: 12),
        _buildSafetyCard(parsed['SAFETY']!),
        _buildVehicleSummaryCard(parsed['VEHICLE SUMMARY']!),
        if (parsed['MESSAGE'] != null)
          _buildCustomReportCard(
            title: "Message Conducteur",
            content: parsed['MESSAGE']!,
            icon: Icons.record_voice_over_outlined,
            iconColor: AppColors.primary,
            leftBarColor: AppColors.primary,
          ),
        if (parsed['DTCS'] != null)
          _buildCustomReportCard(
            title: "Codes DTC Detectes",
            content: parsed['DTCS']!,
            icon: Icons.confirmation_number_outlined,
            iconColor: Colors.indigo,
            leftBarColor: Colors.indigo,
          ),
        if (parsed['EVIDENCE'] != null)
          _buildCustomReportCard(
            title: "Preuves OBD",
            content: parsed['EVIDENCE']!,
            icon: Icons.fact_check_outlined,
            iconColor: Colors.deepOrange,
            leftBarColor: Colors.deepOrange,
          ),
        if (parsed['ROOT CAUSE'] != null)
          _buildRootCauseCard(parsed['ROOT CAUSE']!),
        if (parsed['REPAIR'] != null) _buildRepairCard(parsed['REPAIR']!),
        if (parsed['URGENCY'] != null) _buildUrgencyCard(parsed['URGENCY']!),
        if (widget.isHistoryMode) ...[
          const SizedBox(height: 4),
          _buildChatSection(chatVM),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year à $hour:$minute';
  }

  Widget _buildReportHeaderCard(DiagnosticViewModel vm) {
    final vin = vm.lastScanContext?['vin']?.toString() ?? "Non détecté";
    final date = vm.lastScanDate;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isHistoryMode
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.isHistoryMode
                    ? Icons.history_rounded
                    : Icons.verified_rounded,
                color: widget.isHistoryMode
                    ? AppColors.primary
                    : AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isHistoryMode
                        ? "Diagnostic Enregistré"
                        : "Analyse Terminée",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.isHistoryMode && date != null) ...[
                    Text(
                      "Le ${_formatDateTime(date)}",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    "VIN: $vin",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyCard(String safetyText) {
    Color cardBg;
    Color borderColor;
    Color textColor;
    IconData icon;
    String safetyTitle = "Sécurité & Conduite";

    final lower = safetyText.toLowerCase();
    if (lower.contains("do not drive") ||
        lower.contains("danger") ||
        lower.contains("ne pas rouler") ||
        lower.contains("critique")) {
      cardBg = const Color(0xFFFFEBEE);
      borderColor = AppColors.error;
      textColor = AppColors.error;
      icon = Icons.dangerous_rounded;
      safetyTitle = "DANGER - Ne pas rouler";
    } else if (lower.contains("caution") ||
        lower.contains("warning") ||
        lower.contains("attention") ||
        lower.contains("prudence")) {
      cardBg = const Color(0xFFFFF3E0);
      borderColor = AppColors.accent;
      textColor = const Color(0xFFD97706);
      icon = Icons.warning_amber_rounded;
      safetyTitle = "Etat du vehicule - Vigilance requise";
    } else {
      cardBg = const Color(0xFFE8F5E9);
      borderColor = AppColors.success;
      textColor = const Color(0xFF047857);
      icon = Icons.check_circle_rounded;
      safetyTitle = "SÉCURISÉ - Conduite autorisée";
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor.withOpacity(0.5), width: 1.5),
      ),
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  safetyTitle,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              safetyText,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSummaryCard(String summaryText) {
    return _buildCustomReportCard(
      title: "Vehicle Summary",
      content: summaryText,
      icon: Icons.directions_car_rounded,
      iconColor: AppColors.primary,
      leftBarColor: AppColors.primary,
    );
  }

  Widget _buildRootCauseCard(String rootCauseText) {
    return _buildCustomReportCard(
      title: "Cause d'Origine & Preuves",
      content: rootCauseText,
      icon: Icons.analytics_outlined,
      iconColor: Colors.purple,
      leftBarColor: Colors.purple,
    );
  }

  Widget _buildRepairCard(String repairText) {
    if (repairText.contains("→") || repairText.contains("->")) {
      final steps = repairText
          .split(RegExp(r'(?:→|->)'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.divider),
        ),
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.teal, width: 5)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.build_circle_outlined,
                      color: Colors.teal,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Plan de Réparation",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: List.generate(steps.length, (idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0F2F1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                "${idx + 1}",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              steps[idx],
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildCustomReportCard(
      title: "Plan de Réparation",
      content: repairText,
      icon: Icons.build_circle_outlined,
      iconColor: Colors.teal,
      leftBarColor: Colors.teal,
    );
  }

  Widget _buildUrgencyCard(String urgencyText) {
    Color badgeBg;
    Color badgeText;
    final lower = urgencyText.toLowerCase();

    if (lower.contains("now") ||
        lower.contains("immédiat") ||
        lower.contains("urgent") ||
        lower.contains("tout de suite")) {
      badgeBg = const Color(0xFFFFEBEE);
      badgeText = AppColors.error;
    } else if (lower.contains("week") || lower.contains("cette semaine")) {
      badgeBg = const Color(0xFFFFF3E0);
      badgeText = AppColors.accent;
    } else {
      badgeBg = const Color(0xFFE0F2FE);
      badgeText = Colors.blue.shade700;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.blueGrey, width: 5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.alarm_on_rounded,
                color: Colors.blueGrey,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                "Urgence :",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  urgencyText,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomReportCard({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required Color leftBarColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: leftBarColor, width: 5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatSection(ChatViewModel chatVM) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Historique de chat",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._buildChatMessages(chatVM),
          _buildChatInput(chatVM),
        ],
      ),
    );
  }

  Widget _buildChatPanel(ChatViewModel chatVM) {
    final bool isExpanded = _currentSheetSize > 0.2;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.12, 1.0],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        if (_sheetController.size < 0.2) {
                          _sheetController.animateTo(
                            1.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        } else {
                          _sheetController.animateTo(
                            0.12,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Poser une question sur ce diagnostic",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    if (isExpanded) ...[
                      ..._buildChatMessages(chatVM, scrollController),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              if (isExpanded) _buildChatInput(chatVM),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildChatMessages(
    ChatViewModel chatVM, [
    ScrollController? scrollController,
  ]) {
    if (scrollController != null) _scrollToBottom(scrollController);

    // Filter out internal scan messages and the diagnostic report from the chat view.
    final displayMessages = chatVM.chatHistory.where((m) {
      final content = m.content;
      if (content == null || content.isEmpty) return false;
      if (_isInternalScanTrigger(m)) return false;
      if (_isDiagnosticReportMessage(m)) return false;
      return true;
    }).toList();

    if (displayMessages.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.smart_toy, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Je suis votre assistant IA. Comment puis-je vous aider avec ce diagnostic ? Posez-moi une question sur la gravite, les causes, les reparations ou le cout estime.",
                    style: GoogleFonts.outfit(
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return displayMessages.map((message) {
      final isUser = message.role == MessageRole.user;
      final cleanContent = (message.content ?? "")
          .replaceAll('**', '')
          .replaceAll('*', '')
          .trim();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.smart_toy, size: 20, color: Colors.white),
              ),
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 0),
                    bottomRight: Radius.circular(isUser ? 0 : 16),
                  ),
                ),
                child: Text(
                  cleanContent,
                  style: GoogleFonts.outfit(
                    color: isUser ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (isUser) const SizedBox(width: 8),
            if (isUser)
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
          ],
        ),
      );
    }).toList();
  }

  bool _isInternalScanTrigger(ChatMessage message) {
    return message.role == MessageRole.user &&
        message.content?.trim().toLowerCase() == "faire un diagnostic complet";
  }

  bool _isDiagnosticReportMessage(ChatMessage message) {
    if (message.role != MessageRole.assistant) return false;

    final jsonReport = _tryDecodeJsonMap(message.content ?? "");
    if (jsonReport != null && _looksLikeDiagnosticJson(jsonReport)) {
      return true;
    }

    final normalized = _normalizeReportText(message.content ?? "");
    final hasSafety =
        normalized.contains("SAFETY") || normalized.contains("SECURITE");
    final hasIssue =
        normalized.contains("ISSUE") || normalized.contains("PROBLEME");
    final hasCause =
        normalized.contains("ROOT CAUSE") ||
        normalized.contains("CAUSE ORIGINE");
    final hasRepair =
        normalized.contains("REPAIR") || normalized.contains("REPARATION");
    final hasUrgency =
        normalized.contains("URGENCY") || normalized.contains("URGENCE");

    return hasSafety && hasIssue && (hasCause || hasRepair || hasUrgency);
  }

  String _normalizeReportText(String value) {
    return value
        .toUpperCase()
        .replaceAll("É", "E")
        .replaceAll("È", "E")
        .replaceAll("Ê", "E")
        .replaceAll("Ë", "E")
        .replaceAll("À", "A")
        .replaceAll("Â", "A")
        .replaceAll("Ù", "U")
        .replaceAll("Û", "U")
        .replaceAll("Ç", "C");
  }

  Widget _buildChatInput(ChatViewModel chatVM) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                enabled: !chatVM.isAsking,
                decoration: InputDecoration(
                  hintText: "Posez une question sur le scan...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (val) {
                  if (val.isNotEmpty) {
                    chatVM.sendMessage(val);
                    _chatController.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            chatVM.isAsking
                ? const SizedBox(
                    width: 48,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () {
                        if (_chatController.text.isNotEmpty) {
                          chatVM.sendMessage(_chatController.text);
                          _chatController.clear();
                        }
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
