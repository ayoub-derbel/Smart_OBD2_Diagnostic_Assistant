import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/design_system/sensor_tile_widget.dart';
import '../widgets/design_system/action_card_widget.dart';
import '../providers/obd_data_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/navigation_provider.dart';
import 'elm_connection_screen.dart';
import 'package:provider/provider.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<ObdDataProvider>(
          builder: (context, obdData, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  // Header
                  _buildHeader(context),
                  const SizedBox(height: AppSpacing.md),

                  // ELM connection entry point
                  _buildConnectionButton(context),
                  const SizedBox(height: AppSpacing.xl),

                  // VIN Display
                  _buildVinCard(context, obdData.vin),
                  const SizedBox(height: AppSpacing.lg),

                  // Central Fault Indicator
                  _buildFaultIndicator(context, obdData),
                  const SizedBox(height: AppSpacing.xl),

                  // Telemetry Grid
                  Text(
                    'Telemetry Dashboard',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildSensorGrid(obdData),
                  const SizedBox(height: AppSpacing.xl),

                  // Navigation Cards
                  Row(
                    children: [
                      ActionCardWidget(
                        icon: Icons.medical_services_rounded,
                        title: 'Scan DTCs',
                        subtitle: 'View fault list',
                        tintColor: AppColors.primary,
                        onTap: () => Provider.of<NavigationProvider>(
                          context,
                          listen: false,
                        ).setIndex(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Protocol Footer
                  _buildProtocolFooter(context),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, btProvider, _) {
        bool isConnected = btProvider.state == BluetoothState.connected;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart OBD‑II',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isConnected ? AppColors.success : AppColors.error)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color:
                              (isConnected
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        isConnected ? 'ELM327 Active' : 'Disconnected',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isConnected
                              ? AppColors.success
                              : AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isConnected
                          ? btProvider.connectedDevice?.name ?? 'Unknown Device'
                          : 'No connection',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.settings_rounded,
                color: AppColors.secondaryText,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: const CircleBorder(),
                side: const BorderSide(color: AppColors.divider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionButton(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, btProvider, _) {
        final isConnected = btProvider.state == BluetoothState.connected;
        final isBusy =
            btProvider.state == BluetoothState.scanning ||
            btProvider.state == BluetoothState.connecting;
        final subtitle = isConnected
            ? btProvider.connectedDevice?.name ?? 'ELM327 connecte'
            : isBusy
            ? 'Connexion en cours...'
            : 'Veuillez d\'abord vous connecter';

        return Material(
          color: const Color(0xFF14395A),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () => _openConnectionScreen(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Icon(
                      isConnected
                          ? Icons.check_circle_rounded
                          : Icons.directions_car_filled_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'Connecte' : 'Connexion',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (isBusy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openConnectionScreen(BuildContext context) {
    final navigator = Navigator.of(context);

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ElmConnectionScreen(
          showSkip: false,
          showClose: true,
          title: 'Connexion',
          subtitle:
              'Selectionnez votre adaptateur ELM327 pour lancer le diagnostic.',
          onSkip: () => navigator.pop(),
          onConnected: () => navigator.pop(),
        ),
      ),
    );
  }

  Widget _buildVinCard(BuildContext context, String? vin) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              color: AppColors.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Identification Number',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                Text(
                  vin ?? '--- --- --- --- ---',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.content_copy_rounded,
            size: 18,
            color: AppColors.secondaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildFaultIndicator(BuildContext context, ObdDataProvider obdData) {
    int faultCount = obdData.dtcs.length;
    bool hasFaults = faultCount > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: hasFaults ? 1.0 : 0.0,
                  strokeWidth: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasFaults ? AppColors.error : AppColors.success,
                  ),
                ),
              ),
              Icon(
                hasFaults ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: hasFaults ? AppColors.error : AppColors.success,
                size: 32,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${obdData.vin == null ? "--" : faultCount} Active Faults',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  obdData.vin == null
                      ? 'Not connected to vehicle'
                      : (hasFaults
                            ? 'DTCs detected in system'
                            : 'All systems clear'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => obdData.fetchDtcs(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Rescan'),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid(ObdDataProvider obdData) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.9,
      children: [
        SensorTileWidget(
          icon: Icons.thermostat_rounded,
          title: 'Engine Temp',
          value: obdData.coolantTemp?.toString() ?? '---',
          unit: '°C',
          status: obdData.coolantTemp == null
              ? 'No Data'
              : (obdData.coolantTemp! > 100 ? 'Hot' : 'Optimal'),
          statusColor: obdData.coolantTemp == null
              ? AppColors.secondaryText
              : (obdData.coolantTemp! > 100
                    ? AppColors.error
                    : AppColors.success),
        ),
        SensorTileWidget(
          icon: Icons.speed_rounded,
          title: 'RPM',
          value: obdData.rpm?.toString() ?? '---',
          unit: 'rpm',
          status: obdData.rpm == null
              ? 'No Data'
              : (obdData.rpm! > 3000 ? 'High' : 'Normal'),
          statusColor: obdData.rpm == null
              ? AppColors.secondaryText
              : (obdData.rpm! > 3000 ? AppColors.accent : AppColors.success),
        ),
        SensorTileWidget(
          icon: Icons.battery_charging_full_rounded,
          title: 'Battery',
          value: obdData.batteryVoltage?.toStringAsFixed(1) ?? '---',
          unit: 'V',
          status: obdData.batteryVoltage == null
              ? 'No Data'
              : (obdData.batteryVoltage! < 12.0 ? 'Low' : 'Correct'),
          statusColor: obdData.batteryVoltage == null
              ? AppColors.secondaryText
              : (obdData.batteryVoltage! < 12.0
                    ? AppColors.error
                    : AppColors.success),
        ),
        SensorTileWidget(
          icon: Icons.shutter_speed_rounded,
          title: 'Speed',
          value: obdData.speed?.toString() ?? '---',
          unit: 'km/h',
          status: obdData.speed == null
              ? 'No Data'
              : (obdData.speed! > 0 ? 'Driving' : 'Idle'),
          statusColor: obdData.speed == null
              ? AppColors.secondaryText
              : (obdData.speed! > 0
                    ? AppColors.primary
                    : AppColors.secondaryText),
        ),
        SensorTileWidget(
          icon: Icons.air_rounded,
          title: 'MAF',
          value: obdData.maf?.toStringAsFixed(1) ?? '---',
          unit: 'g/s',
          status: obdData.maf == null ? 'No Data' : 'Direct',
        ),
        SensorTileWidget(
          icon: Icons.analytics_rounded,
          title: 'Engine Load',
          value: obdData.engineLoad?.toStringAsFixed(0) ?? '---',
          unit: '%',
          status: obdData.engineLoad == null ? 'No Data' : 'Normal',
        ),
      ],
    );
  }

  Widget _buildProtocolFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryText,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Protocol: ISO 15765-4 (CAN)',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white60),
              ),
              Text(
                'Sampling Rate: 5 Hz',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            child: Text(
              'Bus Load: 3.2%',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
