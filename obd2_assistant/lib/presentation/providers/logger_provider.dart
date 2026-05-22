import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/repositories/obd_bluetooth_repository.dart';

class LogEntry {
  final DateTime timestamp;
  final String title;
  final String detail;
  final String comment;
  final LogLevel level;

  LogEntry({
    required this.title,
    this.detail = '',
    this.comment = '',
    this.level = LogLevel.info,
  }) : timestamp = DateTime.now();
}

enum LogLevel { info, warning, error, command }

class LoggerProvider with ChangeNotifier {
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);
  StreamSubscription? _subscription;

  void init(ObdBluetoothRepository repository) {
    _subscription?.cancel();
    _subscription = repository.logStream.listen((data) {
      final String title = data['title'] as String;
      final String detail = data['detail'] as String;
      final bool isError = data['isError'] as bool;
      
      log(
        title, 
        detail: detail, 
        level: isError ? LogLevel.error : LogLevel.command,
        comment: getCommandComment(title),
      );
    });
  }

  void log(String title, {String detail = '', LogLevel level = LogLevel.info, String? comment}) {
    _logs.insert(0, LogEntry(
      title: title, 
      detail: detail, 
      level: level,
      comment: comment ?? '',
    ));
    if (_logs.length > 100) _logs.removeLast();
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  String getCommandComment(String hex) {
    hex = hex.toUpperCase().trim();
    if (hex.startsWith('AT')) {
      if (hex.contains('Z')) return 'Resetting Adapter';
      if (hex.contains('E0')) return 'Echo Off';
      if (hex.contains('L0')) return 'Linefeeds Off';
      if (hex.contains('SP0')) return 'Auto Protocol Detection';
      if (hex.contains('RV')) return 'Battery Voltage';
      return 'Adapter Configuration';
    }
    
    final map = {
      '010C': 'Requesting Engine RPM',
      '010D': 'Requesting Vehicle Speed',
      '0104': 'Requesting Calculated Engine Load',
      '0105': 'Requesting Engine Coolant Temp',
      '0110': 'Requesting MAF Air Flow Rate',
      '0902': 'Requesting Vehicle VIN',
      '03': 'Requesting Stored DTCs (Trouble Codes)',
      '07': 'Requesting Pending DTCs',
      '0100': 'Requesting Supported PIDs [01-20]',
    };

    return map[hex] ?? 'Sending OBD Command';
  }

  Future<void> exportLogs() async {
    final buffer = StringBuffer();
    buffer.writeln("Smart OBD-II Assistant - Console Logs Export");
    buffer.writeln("Exported on: ${DateTime.now()}");
    buffer.writeln("--------------------------------------------\n");
    
    // Logs are stored in reverse (newest first), so we reverse again for chronological order
    for (final log in _logs.reversed) {
      buffer.writeln("[${log.timestamp}] ${log.comment}");
      buffer.writeln("> ${log.title}");
      if (log.detail.isNotEmpty) buffer.writeln("  Detail: ${log.detail}");
      buffer.writeln("");
    }
    
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/obd2_logs.txt');
      await file.writeAsString(buffer.toString());
      
      await Share.shareXFiles([XFile(file.path)], text: 'OBD2 Assistant Logs');
    } catch (e) {
      debugPrint("Export error: $e");
    }
  }
}
