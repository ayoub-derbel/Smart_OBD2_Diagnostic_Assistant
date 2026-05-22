import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/logger_provider.dart';
import '../../domain/entities/bluetooth_device_entity.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
              Text(
                'Settings',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              _buildSectionTitle(context, '🔌 ELM327 Connection'),
              _buildConnectionCard(context),
              const SizedBox(height: AppSpacing.xl),
              
              _buildSectionTitle(context, 'ℹ️ About'),
              _buildAboutCard(context),
              const SizedBox(height: AppSpacing.xl),

              _buildSectionTitle(context, '💻 Debug Console'),
              _buildDebugConsole(context),
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.secondaryText),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
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
                      'Connected', 
                      isConnected: true,
                      onTap: () => provider.disconnect(),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ),
              if (provider.devices.isNotEmpty && provider.state != BluetoothState.connected)
                ...provider.devices.map((device) => Column(
                  children: [
                    _buildListTile(
                      context, 
                      device.name, 
                      device.id, 
                      onTap: () => provider.connect(device),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                )),
              if (provider.devices.isEmpty && provider.state != BluetoothState.scanning && provider.connectedDevice == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('No devices found. Press Scan.', style: TextStyle(color: AppColors.secondaryText)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    ),
                    child: Text(provider.state == BluetoothState.scanning ? 'Scanning...' : 'Scan for Devices'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildAboutCard(BuildContext context) {
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
            'Smart OBD‑II Diagnostic Assistant',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Final Year Project - Embedded Systems Engineering - 2026',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Supervisor: Pr. [Name]',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String title, String subtitle, {bool isConnected = false, VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: isConnected 
        ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
        : null,
      onTap: onTap,
    );
  }

  Widget _buildTextField(BuildContext context, String label, String value, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: value),
          obscureText: isPassword,
          readOnly: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (val) {},
      activeColor: AppColors.primary,
    );
  }

  Widget _buildDebugConsole(BuildContext context) {
    return Consumer<LoggerProvider>(
      builder: (context, logger, child) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Dark terminal color
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              // Console Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    const Text(
                      'Terminal Output',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.ios_share_rounded, color: Colors.white54, size: 20),
                          onPressed: () => logger.exportLogs(),
                          tooltip: 'Export Logs',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54, size: 20),
                          onPressed: () => logger.clear(),
                          tooltip: 'Clear Console',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Console Body
              Expanded(
                child: logger.logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No logs yet. Start scanning or connect to see activity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white30, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: logger.logs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = logger.logs[index];
                          Color color = Colors.greenAccent;
                          if (log.level == LogLevel.error) color = Colors.redAccent;
                          if (log.level == LogLevel.warning) color = Colors.orangeAccent;
                          if (log.level == LogLevel.info) color = Colors.blueAccent;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "[${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}] ",
                                    style: const TextStyle(color: Colors.white30, fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                  Text(
                                    log.comment,
                                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "> ${log.title}",
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                              ),
                              if (log.detail.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 2),
                                  child: Text(
                                    log.detail,
                                    style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
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
