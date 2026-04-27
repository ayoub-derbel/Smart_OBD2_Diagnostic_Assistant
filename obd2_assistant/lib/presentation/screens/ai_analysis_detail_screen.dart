import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/design_system/analysis_section_widget.dart';
import '../providers/diagnostic_provider.dart';
import '../providers/obd_data_provider.dart';

class AiAnalysisDetailScreen extends StatefulWidget {
  final String dtcCode;

  const AiAnalysisDetailScreen({
    Key? key,
    required this.dtcCode,
  }) : super(key: key);

  @override
  State<AiAnalysisDetailScreen> createState() => _AiAnalysisDetailScreenState();
}

class _AiAnalysisDetailScreenState extends State<AiAnalysisDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Lancer l'analyse au chargement de l'écran
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final obdData = Provider.of<ObdDataProvider>(context, listen: false);
      final carModel = obdData.vin ?? "Véhicule Standard OBD-II";
      context.read<DiagnosticProvider>().analyze(widget.dtcCode, carModel);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IA Analysis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Code: ${widget.dtcCode}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
      body: Consumer<DiagnosticProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return _buildLoadingState();
          }

          if (provider.error != null) {
            return _buildErrorState(provider.error!);
          }

          if (provider.result == null) {
            return _buildEmptyState();
          }

          final result = provider.result!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      if (result.identifiedVehicle != null && result.identifiedVehicle!.isNotEmpty) ...[
                        AnalysisSectionWidget(
                          title: 'Véhicule Identifié',
                          icon: Icons.directions_car_rounded,
                          iconColor: AppColors.secondary,
                          iconBg: AppColors.secondary.withOpacity(0.1),
                          child: Text(
                            result.identifiedVehicle!,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const Divider(height: AppSpacing.xl, color: AppColors.divider),
                      ],
                      AnalysisSectionWidget(
                        title: 'Résumé du Problème',
                        icon: Icons.description_rounded,
                        iconColor: AppColors.primary,
                        iconBg: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          result.interpretation,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: AppColors.primaryText),
                        ),
                      ),
                      const Divider(height: AppSpacing.xl, color: AppColors.divider),
                      AnalysisSectionWidget(
                        title: 'Causes Probables',
                        icon: Icons.search_rounded,
                        iconColor: AppColors.accent,
                        iconBg: AppColors.accent.withOpacity(0.1),
                        child: Text(
                          result.possibleCauses,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: AppColors.primaryText),
                        ),
                      ),
                      const Divider(height: AppSpacing.xl, color: AppColors.divider),
                      AnalysisSectionWidget(
                        title: 'Actions Recommandées',
                        icon: Icons.build_rounded,
                        iconColor: AppColors.success,
                        iconBg: AppColors.success.withOpacity(0.1),
                        child: Text(
                          result.troubleshootingSteps,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: AppColors.primaryText),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildFreezeFrameSection(context),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Export PDF'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'L\'IA analyse votre véhicule...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Cela peut prendre quelques secondes',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 64),
            const SizedBox(height: AppSpacing.md),
            Text('Erreur d\'analyse', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                final obdData = Provider.of<ObdDataProvider>(context, listen: false);
                context.read<DiagnosticProvider>().analyze(widget.dtcCode, obdData.vin ?? "Véhicule");
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('Aucune donnée d\'analyse disponible.'));
  }

  Widget _buildFreezeFrameSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Données Figées (Freeze Frame)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: const [
              _FreezeFrameRow(label: 'Régime Moteur', value: '2,450 rpm'),
              Divider(height: 1, thickness: 0.5),
              _FreezeFrameRow(label: 'Charge Calculée', value: '34.2 %'),
              Divider(height: 1, thickness: 0.5),
              _FreezeFrameRow(label: 'Temp. Liquide Refroid.', value: '87 °C'),
              Divider(height: 1, thickness: 0.5),
              _FreezeFrameRow(label: 'Ajustement Carburant', value: '-2.1 %'),
            ],
          ),
        ),
      ],
    );
  }
}

class _FreezeFrameRow extends StatelessWidget {
  final String label;
  final String value;
  const _FreezeFrameRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
