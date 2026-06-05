import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/logger_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                language.t('settings.title'),
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.xl),

              _buildSectionTitle(context, language.t('settings.language')),
              _buildLanguageCard(context, language),
              const SizedBox(height: AppSpacing.xl),

              _buildSectionTitle(context, language.t('settings.connection')),
              _buildConnectionCard(context, language),
              const SizedBox(height: AppSpacing.xl),

              _buildSectionTitle(context, language.t('settings.about')),
              _buildAboutCard(context, language),
              const SizedBox(height: AppSpacing.xl),

              _buildSectionTitle(context, language.t('settings.debugConsole')),
              _buildDebugConsole(context, language),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: AppColors.secondaryText),
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: AppLanguage.values.map((language) {
          final isSelected = languageProvider.language == language;

          return Column(
            children: [
              ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.secondaryText,
                ),
                title: Text(
                  language.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primaryText,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                      )
                    : null,
                onTap: () => languageProvider.setLanguage(language),
              ),
              if (language != AppLanguage.values.last)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, LanguageProvider language) {
    return Consumer<BluetoothProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.state == BluetoothState.scanning)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (provider.connectedDevice != null)
                Column(
                  children: [
                    _buildListTile(
                      context,
                      provider.connectedDevice!.name,
                      language.t('settings.connected'),
                      isConnected: true,
                      onTap: () => provider.disconnect(),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ),
              if (provider.devices.isNotEmpty &&
                  provider.state != BluetoothState.connected)
                ...provider.devices.map(
                  (device) => Column(
                    children: [
                      _buildListTile(
                        context,
                        device.name,
                        device.id,
                        onTap: () => provider.connect(device),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ),
                ),
              if (provider.devices.isEmpty &&
                  provider.state != BluetoothState.scanning &&
                  provider.connectedDevice == null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    language.t('settings.noDevices'),
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: provider.state == BluetoothState.scanning
                        ? null
                        : () => provider.startScan(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: Text(
                      provider.state == BluetoothState.scanning
                          ? language.t('settings.scanning')
                          : language.t('settings.scanDevices'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutCard(BuildContext context, LanguageProvider language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart OBD-II Diagnostic Assistant',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            language.t('settings.project'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            language.t('settings.supervisor'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            language.t('settings.version'),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    String title,
    String subtitle, {
    bool isConnected = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: isConnected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildDebugConsole(BuildContext context, LanguageProvider language) {
    return Consumer<LoggerProvider>(
      builder: (context, logger, child) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadii.lg),
                    topRight: Radius.circular(AppRadii.lg),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.t('settings.terminalOutput'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () => logger.exportLogs(),
                          tooltip: language.t('settings.exportLogs'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () => logger.clear(),
                          tooltip: language.t('settings.clearConsole'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logger.logs.isEmpty
                    ? Center(
                        child: Text(
                          language.t('settings.noLogs'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: logger.logs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = logger.logs[index];
                          Color color = Colors.greenAccent;
                          if (log.level == LogLevel.error) {
                            color = Colors.redAccent;
                          }
                          if (log.level == LogLevel.warning) {
                            color = Colors.orangeAccent;
                          }
                          if (log.level == LogLevel.info) {
                            color = Colors.blueAccent;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "[${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}] ",
                                    style: const TextStyle(
                                      color: Colors.white30,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    log.comment,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "> ${log.title}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (log.detail.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    top: 2,
                                  ),
                                  child: Text(
                                    log.detail,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
