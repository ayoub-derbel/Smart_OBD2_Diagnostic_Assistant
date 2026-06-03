import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../providers/full_diagnostic_view_model.dart';
import '../../domain/entities/full_diagnostic_report.dart';

class FullDiagnosticScreen extends StatelessWidget {
  const FullDiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Diagnostic Complet",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<FullDiagnosticViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return _buildLoadingState();
          }

          if (vm.error != null) {
            return _buildErrorState(vm);
          }

          final report = vm.report;
          if (report == null) {
            return _buildEmptyState(vm);
          }

          return _buildReportContent(context, vm, report);
        },
      ),
    );
  }

  // ─── Loading State ─────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Diagnostic en cours...",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Lecture des codes d'erreur et des capteurs OBD-II...",
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Analyse intelligente avec Groq AI...",
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error State ───────────────────────────────────────────────────────────
  Widget _buildErrorState(FullDiagnosticViewModel vm) {
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
              vm.error ?? "Une erreur inattendue est survenue.",
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
                onPressed: vm.runDiagnostic,
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

  // ─── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(FullDiagnosticViewModel vm) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              "Diagnostic Complet OBD-II",
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Obtenez un aperçu complet des problèmes de votre véhicule, les causes probables et un plan de réparation structuré.",
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
                      "Détection automatique des DTCs et PIDs",
                    ),
                    const Divider(height: 24),
                    _buildFeatureRow(
                      Icons.psychology_rounded,
                      "Analyse IA des causes probables",
                    ),
                    const Divider(height: 24),
                    _buildFeatureRow(
                      Icons.build_circle_outlined,
                      "Plan de réparation étape par étape",
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
                onPressed: vm.runDiagnostic,
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

  // ─── Report Content ────────────────────────────────────────────────────────
  Widget _buildReportContent(
    BuildContext context,
    FullDiagnosticViewModel vm,
    FullDiagnosticReport report,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Report header
        _buildReportHeaderCard(vm),
        const SizedBox(height: 12),

        // Safety / Overview card
        _buildOverviewCard(report.overview),

        // Problems
        if (report.problems.isNotEmpty) _buildProblemsCard(report.problems),

        // Causes
        if (report.causes.isNotEmpty) _buildCausesCard(report.causes),

        // Repair Plan
        _buildRepairPlanCard(report.repairPlan),

        const SizedBox(height: 16),

        // Re-run button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: vm.runDiagnostic,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              "Relancer le Diagnostic",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Report Header Card ────────────────────────────────────────────────────
  Widget _buildReportHeaderCard(FullDiagnosticViewModel vm) {
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
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Analyse Terminée",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rapport généré avec succès",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w500,
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

  // ─── Overview / Safety Card ────────────────────────────────────────────────
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
      safetyTitle = "DANGER";
    } else if (status == "caution" || status == "warning") {
      cardBg = const Color(0xFFFFF3E0);
      borderColor = AppColors.accent;
      textColor = const Color(0xFFD97706);
      icon = Icons.warning_amber_rounded;
      safetyTitle = "ATTENTION";
    } else {
      cardBg = const Color(0xFFE8F5E9);
      borderColor = AppColors.success;
      textColor = const Color(0xFF047857);
      icon = Icons.check_circle_rounded;
      safetyTitle = "VÉHICULE SAIN";
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

  // ─── Problems Card ─────────────────────────────────────────────────────────
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
            border: Border(
              left: BorderSide(color: AppColors.error, width: 5),
            ),
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

  // ─── Causes Card ───────────────────────────────────────────────────────────
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
            border: Border(
              left: BorderSide(color: Colors.purple, width: 5),
            ),
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

  // ─── Repair Plan Card ──────────────────────────────────────────────────────
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
            border: Border(
              left: BorderSide(color: Colors.teal, width: 5),
            ),
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

              // Urgency & Difficulty row
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

              // Steps
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
}
