import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../providers/bluetooth_provider.dart';

class ElmConnectionScreen extends StatelessWidget {
  final VoidCallback onSkip;
  final VoidCallback? onConnected;
  final bool showSkip;
  final bool showClose;
  final String title;
  final String subtitle;

  const ElmConnectionScreen({
    super.key,
    required this.onSkip,
    this.onConnected,
    this.showSkip = true,
    this.showClose = false,
    this.title = 'Connexion ELM327',
    this.subtitle =
        'Connectez-vous a un adaptateur ELM pour activer le diagnostic en direct.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showClose)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: onSkip,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fermer',
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ElmConnectionPanel(onConnected: onConnected),
              if (showSkip) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onSkip,
                    child: const Text('Passer pour le moment'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ElmConnectionPanel extends StatelessWidget {
  final VoidCallback? onConnected;

  const _ElmConnectionPanel({this.onConnected});

  Future<void> _connect(
    BuildContext context,
    BluetoothProvider provider,
    BluetoothDeviceEntity device,
  ) async {
    await provider.connect(device);
    if (context.mounted && provider.state == BluetoothState.connected) {
      onConnected?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, provider, child) {
        final isScanning = provider.state == BluetoothState.scanning;
        final isConnecting = provider.state == BluetoothState.connecting;
        final isConnected = provider.state == BluetoothState.connected;
        final isBusy = isScanning || isConnecting;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            (isConnected
                                    ? AppColors.success
                                    : AppColors.primary)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.check_circle_rounded
                            : Icons.bluetooth_searching_rounded,
                        color: isConnected
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected
                                ? 'Adaptateur connecte'
                                : 'Adaptateur ELM',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isConnected
                                ? provider.connectedDevice?.name ?? 'ELM327'
                                : 'Recherchez puis selectionnez votre ELM327.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Text(
                    provider.errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                  ),
                ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: LinearProgressIndicator(),
                ),
              if (provider.devices.isEmpty && !isBusy && !isConnected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Text(
                    'Aucun adaptateur detecte pour le moment.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (provider.devices.isNotEmpty && !isConnected)
                ...provider.devices.map(
                  (device) => Column(
                    children: [
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.bluetooth_connected_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(device.name),
                        subtitle: Text(device.id),
                        trailing: isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: isBusy
                            ? null
                            : () => _connect(context, provider, device),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isBusy
                            ? null
                            : isConnected
                            ? onConnected
                            : provider.startScan,
                        icon: Icon(
                          isConnected
                              ? Icons.arrow_forward_rounded
                              : Icons.bluetooth_searching_rounded,
                        ),
                        label: Text(
                          isConnected
                              ? 'Continuer'
                              : isScanning
                              ? 'Recherche en cours...'
                              : 'Rechercher un adaptateur',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: provider.disconnect,
                          icon: const Icon(Icons.link_off_rounded),
                          label: const Text('Deconnecter'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
