import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/providers/diagnostic_provider.dart';
import 'presentation/providers/bluetooth_provider.dart';
import 'presentation/providers/obd_data_provider.dart';
import 'presentation/providers/navigation_provider.dart';
import 'presentation/providers/full_diagnostic_view_model.dart';
import 'presentation/providers/language_provider.dart';
import 'presentation/providers/logger_provider.dart';
import 'data/datasources/ai_api_service.dart';
import 'data/repositories/obd_bluetooth_repository_factory.dart';
import 'data/repositories/chat_history_repository_impl.dart';
import 'data/repositories/diagnostic_session_repository_impl.dart';
import 'data/repositories/scan_history_repository_impl.dart';
import 'data/services/obd2_service_impl.dart';
import 'domain/agents/diagnostic_agent.dart';
import 'domain/agents/smart_diagnostic_agent.dart';
import 'presentation/providers/diagnostic_view_model.dart';
import 'presentation/providers/chat_view_model.dart';
import 'presentation/screens/connection_gate_screen.dart';
import 'data/services/obd2_service.dart';

import 'data/services/mock_obd2_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OBD2AssistantApp());
  unawaited(_initializeFirebase());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint("Erreur d'initialisation Firebase: $e");
  }
}

class OBD2AssistantApp extends StatelessWidget {
  const OBD2AssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bluetoothRepository = createObdBluetoothRepository();

    // Utilisation du mock pour les tests (forcé pour ce build mobile)
    final Obd2Service obd2Service =
        true // Remplacer par kIsWeb pour revenir au comportement normal
        ? MockObd2Service()
        : Obd2ServiceImpl(bluetoothRepository);

    final aiService = AiApiService();
    final chatRepo = ChatHistoryRepositoryImpl();
    final scanHistoryRepo = ScanHistoryRepositoryImpl();
    final sessionRepo = DiagnosticSessionRepositoryImpl();
    final diagnosticAgent = DiagnosticAgent(obd2Service, aiService);
    final smartAgent = SmartDiagnosticAgent(
      obd2Service,
      aiService,
      chatRepo,
      scanHistoryRepo,
      sessionRepo,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiagnosticProvider()),
        ChangeNotifierProvider(
          create: (_) => BluetoothProvider(bluetoothRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ObdDataProvider(bluetoothRepository),
        ),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(
          create: (_) => FullDiagnosticViewModel(diagnosticAgent),
        ),
        ChangeNotifierProvider(create: (_) => DiagnosticViewModel(smartAgent)),
        ChangeNotifierProvider(create: (_) => ChatViewModel(smartAgent)),
        ChangeNotifierProvider(
          create: (_) => LoggerProvider()..init(bluetoothRepository),
        ),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp(
            title: 'OBD2 Assistant',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: languageProvider.locale,
            supportedLocales: AppLanguage.values
                .map((language) => language.locale)
                .toList(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: languageProvider.textDirection,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const ConnectionGateScreen(),
          );
        },
      ),
    );
  }
}
