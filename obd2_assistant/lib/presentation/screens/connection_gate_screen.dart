import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import 'elm_connection_screen.dart';
import 'main_screen.dart';

class ConnectionGateScreen extends StatefulWidget {
  const ConnectionGateScreen({super.key});

  @override
  State<ConnectionGateScreen> createState() => _ConnectionGateScreenState();
}

class _ConnectionGateScreenState extends State<ConnectionGateScreen> {
  bool _showMainScreen = false;

  void _openHome() {
    Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
    setState(() {
      _showMainScreen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showMainScreen) {
      return const MainScreen();
    }

    return ElmConnectionScreen(onSkip: _openHome, onConnected: _openHome);
  }
}
