import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../providers/full_diagnostic_view_model.dart';

class FullDiagnosticScreen extends StatelessWidget {
  const FullDiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Diagnostic Complet"),
      ),
      body: Consumer<FullDiagnosticViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("Collecting and analyzing data..."),
                ],
              ),
            );
          }

          if (vm.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 42),
                    const SizedBox(height: 12),
                    Text(vm.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: vm.runDiagnostic,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }

          final report = vm.report;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ElevatedButton.icon(
                onPressed: vm.runDiagnostic,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("Run Full Diagnostic"),
              ),
              const SizedBox(height: 16),
              if (report == null)
                const Text("No report available yet.")
              else ...[
                _SectionCard(
                  title: "Identified Vehicle",
                  child: Text(report.vehicleInfo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                _SectionCard(
                  title: "Summary",
                  child: Text(report.vehicleSummary),
                ),
                _SectionCard(
                  title: "Global Health",
                  child: _GlobalHealthBadge(health: report.globalHealth),
                ),
                _SectionCard(
                  title: "Technical Reasoning",
                  child: Text(report.logicExplanation, style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
                if (report.abnormalPids.isNotEmpty)
                  _SectionCard(
                    title: "Abnormal Sensors",
                    child: Column(
                      children: report.abnormalPids.map((pid) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("${pid.pid}: ${pid.value}"),
                        subtitle: Text(pid.reason, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                        leading: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                      )).toList(),
                    ),
                  ),
                _SectionCard(
                  title: "Detected Issues",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: report.issues
                        .map(
                          (issue) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${issue.title} [${issue.severity}]",
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text("Cause: ${issue.probableCause}"),
                                Text("Action: ${issue.recommendation}"),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                _SectionCard(
                  title: "Immediate Actions",
                  child: _StringList(items: report.immediateActions),
                ),
                _SectionCard(
                  title: "Preventive Actions",
                  child: _StringList(items: report.preventiveActions),
                ),
              ]
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _StringList extends StatelessWidget {
  final List<String> items;
  const _StringList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text("No data");
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Text("• $item")).toList(),
    );
  }
}

class _GlobalHealthBadge extends StatelessWidget {
  final String health;
  const _GlobalHealthBadge({required this.health});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (health.toLowerCase()) {
      case "healthy":
        color = AppColors.success;
        text = "Healthy";
        icon = Icons.check_circle_outline;
        break;
      case "warning":
        color = AppColors.accent;
        text = "Warning";
        icon = Icons.warning_amber_rounded;
        break;
      case "critical":
        color = AppColors.error;
        text = "Critical";
        icon = Icons.dangerous_outlined;
        break;
      default:
        color = AppColors.secondary;
        text = "Unknown";
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
