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
                  Text("Collecte et analyse en cours..."),
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
                      child: const Text("Reessayer"),
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
                label: const Text("Lancer Diagnostic complet"),
              ),
              const SizedBox(height: 16),
              if (report == null)
                const Text("Aucun rapport pour le moment.")
              else ...[
                _SectionCard(
                  title: "Resume Vehicule",
                  child: Text(report.vehicleSummary),
                ),
                _SectionCard(
                  title: "Etat Global",
                  child: Text(report.globalHealth),
                ),
                _SectionCard(
                  title: "Problemes Detectes",
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
                  title: "Actions Immediates",
                  child: _StringList(items: report.immediateActions),
                ),
                _SectionCard(
                  title: "Actions Preventives",
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
      return const Text("Aucune donnee");
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Text("• $item")).toList(),
    );
  }
}
