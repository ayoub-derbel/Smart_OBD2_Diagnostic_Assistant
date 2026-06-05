import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english('en', 'English'),
  french('fr', 'Français'),
  arabic('ar', 'العربية');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  Locale get locale => Locale(code);
  bool get isRtl => this == AppLanguage.arabic;

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

class LanguageProvider extends ChangeNotifier {
  static const String _storageKey = 'selected_language';

  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  TextDirection get textDirection =>
      _language.isRtl ? TextDirection.rtl : TextDirection.ltr;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = AppLanguage.fromCode(prefs.getString(_storageKey));
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;

    _language = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, language.code);
  }

  String t(String key) {
    return _localizedStrings[_language]?[key] ??
        _localizedStrings[AppLanguage.english]?[key] ??
        key;
  }
}

const Map<AppLanguage, Map<String, String>> _localizedStrings = {
  AppLanguage.english: {
    'nav.home': 'Home',
    'nav.diagnostic': 'Diagnostic',
    'nav.smartDiag': 'Smart Diag',
    'nav.settings': 'Settings',
    'settings.title': 'Settings',
    'settings.language': 'Language',
    'settings.connection': 'ELM327 Connection',
    'settings.about': 'About',
    'settings.debugConsole': 'Debug Console',
    'settings.connected': 'Connected',
    'settings.noDevices': 'No devices found. Press Scan.',
    'settings.scanning': 'Scanning...',
    'settings.scanDevices': 'Scan for Devices',
    'settings.project':
        'Final Year Project - Embedded Systems Engineering - 2026',
    'settings.supervisor': 'Supervisor: Pr. [Name]',
    'settings.version': 'Version 1.0.0',
    'settings.terminalOutput': 'Terminal Output',
    'settings.exportLogs': 'Export Logs',
    'settings.clearConsole': 'Clear Console',
    'settings.noLogs':
        'No logs yet. Start scanning or connect to see activity.',
  },
  AppLanguage.french: {
    'nav.home': 'Accueil',
    'nav.diagnostic': 'Diagnostic',
    'nav.smartDiag': 'Diag IA',
    'nav.settings': 'Paramètres',
    'settings.title': 'Paramètres',
    'settings.language': 'Langue',
    'settings.connection': 'Connexion ELM327',
    'settings.about': 'À propos',
    'settings.debugConsole': 'Console de débogage',
    'settings.connected': 'Connecté',
    'settings.noDevices': 'Aucun appareil trouvé. Appuyez sur Scan.',
    'settings.scanning': 'Recherche...',
    'settings.scanDevices': 'Scanner les appareils',
    'settings.project':
        'Projet de fin d’études - Génie des systèmes embarqués - 2026',
    'settings.supervisor': 'Encadrant : Pr. [Nom]',
    'settings.version': 'Version 1.0.0',
    'settings.terminalOutput': 'Sortie terminal',
    'settings.exportLogs': 'Exporter les logs',
    'settings.clearConsole': 'Effacer la console',
    'settings.noLogs':
        'Aucun log pour le moment. Lancez un scan ou connectez-vous pour voir l’activité.',
  },
  AppLanguage.arabic: {
    'nav.home': 'الرئيسية',
    'nav.diagnostic': 'التشخيص',
    'nav.smartDiag': 'ذكاء التشخيص',
    'nav.settings': 'الإعدادات',
    'settings.title': 'الإعدادات',
    'settings.language': 'اللغة',
    'settings.connection': 'اتصال ELM327',
    'settings.about': 'حول التطبيق',
    'settings.debugConsole': 'وحدة التصحيح',
    'settings.connected': 'متصل',
    'settings.noDevices': 'لم يتم العثور على أجهزة. اضغط على فحص.',
    'settings.scanning': 'جار الفحص...',
    'settings.scanDevices': 'فحص الأجهزة',
    'settings.project': 'مشروع نهاية الدراسة - هندسة الأنظمة المدمجة - 2026',
    'settings.supervisor': 'المشرف: أ. [الاسم]',
    'settings.version': 'الإصدار 1.0.0',
    'settings.terminalOutput': 'مخرجات الطرفية',
    'settings.exportLogs': 'تصدير السجلات',
    'settings.clearConsole': 'مسح وحدة التحكم',
    'settings.noLogs': 'لا توجد سجلات بعد. ابدأ الفحص أو اتصل لعرض النشاط.',
  },
};
