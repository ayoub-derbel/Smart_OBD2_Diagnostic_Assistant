import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'home_dashboard_screen.dart';
import 'diagnostic_screen.dart';
import 'live_data_screen.dart';
import 'full_diagnostic_screen.dart';

import 'settings_screen.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/obd_data_provider.dart';
import '../providers/navigation_provider.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = [
    const HomeDashboardScreen(),
    const DiagnosticScreen(),
    const FullDiagnosticScreen(),
    const LiveDataScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Start/Stop polling based on connection state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothProvider = Provider.of<BluetoothProvider>(context, listen: false);
      final obdDataProvider = Provider.of<ObdDataProvider>(context, listen: false);
      
      bluetoothProvider.addListener(() {
        if (bluetoothProvider.state == BluetoothState.connected) {
          obdDataProvider.startPolling();
        } else {
          obdDataProvider.stopPolling();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    
    return Scaffold(
      body: IndexedStack(
        index: navProvider.selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: navProvider.selectedIndex,
          onTap: (index) => navProvider.setIndex(index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.secondaryText,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services_rounded),
              activeIcon: Icon(Icons.medical_services_rounded),
              label: 'Diagnostic',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_rounded),
              activeIcon: Icon(Icons.fact_check_rounded),
              label: 'Full Diag',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
              activeIcon: Icon(Icons.show_chart_rounded),
              label: 'Live Data',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

