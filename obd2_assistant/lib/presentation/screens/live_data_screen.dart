import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../providers/obd_data_provider.dart';
import 'package:provider/provider.dart';

class LiveDataScreen extends StatelessWidget {
  const LiveDataScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<ObdDataProvider>(
          builder: (context, obdData, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, obdData),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSensorCard(context, 'RPM', '${obdData.rpm ?? "---"} rpm', Colors.blue),
                  const SizedBox(height: AppSpacing.md),
                  _buildSensorCard(context, 'MAF', '${obdData.maf?.toStringAsFixed(2) ?? "---"} g/s', Colors.cyan),
                  const SizedBox(height: AppSpacing.md),
                  _buildSensorCard(context, 'Speed', '${obdData.speed ?? "---"} km/h', Colors.green),
                  const SizedBox(height: AppSpacing.xl),
                  
                  Text(
                    'Quick Overview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildQuickGrid(context, obdData),
                  const SizedBox(height: AppSpacing.xl),
                  
                  _buildFooterMetrics(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ObdDataProvider obdData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Live Data',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: () {
                if (obdData.isPolling) {
                  obdData.stopPolling();
                } else {
                  obdData.startPolling();
                }
              },
              icon: Icon(obdData.isPolling ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                  color: AppColors.secondaryText),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: const CircleBorder(),
                side: const BorderSide(color: AppColors.divider),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard(BuildContext context, String title, String value, Color chartColor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.secondaryText),
              ),
              const Icon(Icons.close_rounded, size: 18, color: AppColors.hint),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              // Dummy Sparkline
              Container(
                width: 120,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: CustomPaint(
                  painter: _SparklinePainter(color: chartColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGrid(BuildContext context, ObdDataProvider obdData) {
    return Row(
      children: [
        _buildCompactTile(context, '⚡ Battery', '${obdData.batteryVoltage?.toStringAsFixed(1) ?? "---"} V'),
        const SizedBox(width: AppSpacing.md),
        _buildCompactTile(context, '🏎️ Speed', '${obdData.speed ?? "---"} km/h'),
        const SizedBox(width: AppSpacing.md),
        _buildCompactTile(context, '🌬️ MAF', '${obdData.maf?.toStringAsFixed(1) ?? "---"}'),
      ],
    );
  }

  Widget _buildCompactTile(BuildContext context, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterMetrics(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildFooterItem(context, Icons.analytics_outlined, 'Sampling Rate:', '5 Hz'),
        _buildFooterItem(context, Icons.update_rounded, 'Last Update:', '0.2 s'),
      ],
    );
  }

  Widget _buildFooterItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.secondaryText),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: AppColors.secondaryText),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  _SparklinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.lineTo(size.width * 0.2, size.height * 0.4);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.6, size.height * 0.2);
    path.lineTo(size.width * 0.8, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.3);

    canvas.drawPath(path, paint);
    
    // Gradient fill
    canvas.drawPath(
      Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
