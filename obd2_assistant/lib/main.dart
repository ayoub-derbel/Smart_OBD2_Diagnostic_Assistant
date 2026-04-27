import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/providers/diagnostic_provider.dart';
import 'presentation/providers/bluetooth_provider.dart';
import 'presentation/providers/obd_data_provider.dart';
import 'presentation/providers/navigation_provider.dart';
import 'presentation/providers/full_diagnostic_view_model.dart';
import 'data/datasources/bluetooth_datasource.dart';
import 'data/datasources/ai_api_service.dart';
import 'data/repositories/obd_bluetooth_repository_impl.dart';
import 'data/services/obd2_service_impl.dart';
import 'domain/agents/diagnostic_agent.dart';
import 'presentation/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Erreur d'initialisation Firebase: $e");
  }
  runApp(const OBD2AssistantApp());
}

class OBD2AssistantApp extends StatelessWidget {
  const OBD2AssistantApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bluetoothDatasource = BluetoothDatasource();
    final bluetoothRepository = ObdBluetoothRepositoryImpl(bluetoothDatasource);
    final obd2Service = Obd2ServiceImpl(bluetoothRepository);
    final diagnosticAgent = DiagnosticAgent(obd2Service, AiApiService());

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiagnosticProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider(bluetoothRepository)),
        ChangeNotifierProvider(create: (_) => ObdDataProvider(bluetoothRepository)),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => FullDiagnosticViewModel(diagnosticAgent)),
      ],
      child: MaterialApp(
        title: 'OBD2 Assistant',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ),
    );
  }
}
