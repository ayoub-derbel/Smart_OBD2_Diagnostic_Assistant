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
import 'presentation/providers/logger_provider.dart';
import 'data/datasources/bluetooth_datasource.dart';
import 'data/datasources/ai_api_service.dart';
import 'data/repositories/obd_bluetooth_repository_impl.dart';
import 'data/repositories/chat_history_repository_impl.dart';
import 'data/repositories/scan_history_repository_impl.dart';
import 'data/services/obd2_service_impl.dart';
import 'domain/agents/diagnostic_agent.dart';
import 'domain/agents/smart_diagnostic_agent.dart';
import 'presentation/providers/smart_diagnostic_view_model.dart';
import 'presentation/screens/main_screen.dart';
import 'data/services/obd2_service.dart';

import 'package:flutter/foundation.dart';
import 'data/services/mock_obd2_service.dart';

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
    
    // Utilisation du mock pour les tests (forcé pour ce build mobile)
    final Obd2Service obd2Service = true // Remplacer par kIsWeb pour revenir au comportement normal
        ? MockObd2Service() 
        : Obd2ServiceImpl(bluetoothRepository);
        
    final aiService = AiApiService();
    final chatRepo = ChatHistoryRepositoryImpl();
    final scanHistoryRepo = ScanHistoryRepositoryImpl();
    final diagnosticAgent = DiagnosticAgent(obd2Service, aiService);
    final smartAgent = SmartDiagnosticAgent(obd2Service, aiService, chatRepo, scanHistoryRepo);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiagnosticProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider(bluetoothRepository)),
        ChangeNotifierProvider(create: (_) => ObdDataProvider(bluetoothRepository)),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => FullDiagnosticViewModel(diagnosticAgent)),
        ChangeNotifierProvider(create: (_) => SmartDiagnosticViewModel(smartAgent)),
        ChangeNotifierProvider(create: (_) => LoggerProvider()..init(bluetoothRepository)),
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
