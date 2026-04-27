import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/design_system/dtc_card_widget.dart';
import '../providers/obd_data_provider.dart';
import '../providers/diagnostic_provider.dart';
import '../providers/navigation_provider.dart';
import 'ai_analysis_detail_screen.dart';
import 'package:provider/provider.dart';

class DiagnosticScreen extends StatelessWidget {
  const DiagnosticScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<ObdDataProvider>(
          builder: (context, obdData, child) {
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.md,
                    bottom: 120, // Space for button
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: AppSpacing.lg),
                      _buildStatusOverview(context, obdData.dtcs.length),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Detected Faults',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (obdData.vin == null)
                        _buildNotConnectedState(context)
                      else if (obdData.dtcs.isEmpty)
                        _buildEmptyState(context)
                      else
                        ...obdData.dtcs.map((dtc) => DtcCardWidget(
                              code: dtc,
                              description: _getBasicDescription(dtc),
                              status: 'Confirmed',
                              onAnalysisPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AiAnalysisDetailScreen(dtcCode: dtc),
                                  ),
                                );
                              },
                            )),
                      const SizedBox(height: AppSpacing.lg),
                      _buildPendingInfo(context),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildScanButtonLayout(context, obdData),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotConnectedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.bluetooth_disabled_rounded, color: AppColors.secondaryText, size: 64),
            const SizedBox(height: AppSpacing.md),
            Text('Not Connected', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Connect to an OBD-II device to run diagnostics.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
            const SizedBox(height: AppSpacing.md),
            Text('No Faults Detected', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Your vehicle systems appear to be healthy.', style: TextStyle(color: AppColors.secondaryText)),
          ],
        ),
      ),
    );
  }

  String _getBasicDescription(String dtc) {
    // Simplified mapping for common codes used in emulator
    if (dtc == "P0101") return "Mass Air Flow Circuit Range/Performance";
    if (dtc == "P0300") return "Random or Multiple Cylinder Misfire Detected";
    if (dtc == "P0171") return "System Too Lean (Bank 1)";
    return "OBD-II Fault Code Detected";
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diagnostic',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Last scan: Today, 14:32',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(2),
              icon: const Icon(Icons.fact_check_rounded, color: AppColors.primary),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: const CircleBorder(),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.history_rounded, color: AppColors.secondaryText),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: const CircleBorder(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusOverview(BuildContext context, int count) {
    bool hasFaults = count > 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: (hasFaults ? AppColors.error : AppColors.success).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: (hasFaults ? AppColors.error : AppColors.success).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            hasFaults ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, 
            color: hasFaults ? AppColors.error : AppColors.success, 
            size: 20
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              hasFaults ? '$count fault codes detected' : 'System healthy',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasFaults ? AppColors.error : AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (hasFaults)
            Text(
              'Priority: High',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.error),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.onSurface, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What are Pending Codes?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pending codes indicate a fault was detected once, but needs to reoccur during the next drive cycle to be confirmed.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButtonLayout(BuildContext context, ObdDataProvider obdData) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => obdData.fetchDtcs(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.refresh_rounded),
            SizedBox(width: AppSpacing.sm),
            Text('Run Full System Scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
