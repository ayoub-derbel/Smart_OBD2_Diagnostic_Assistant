import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/repositories/obd_bluetooth_repository.dart';

class ObdDataProvider extends ChangeNotifier {
  final ObdBluetoothRepository _repository;
  
  ObdDataProvider(this._repository);

  // State (nullable to handle 'no data' state)
  int? rpm;
  int? speed;
  double? maf;
  int? coolantTemp;
  double? batteryVoltage;
  double? engineLoad;
  String? vin;
  List<String> dtcs = [];
  bool isPolling = false;
  Timer? _timer;

  void resetData() {
    rpm = null;
    speed = null;
    maf = null;
    coolantTemp = null;
    batteryVoltage = null;
    engineLoad = null;
    vin = null;
    dtcs = [];
    notifyListeners();
  }

  Future<void> startPolling() async {
    if (isPolling) return;
    isPolling = true;
    _addLog("Starting OBD Polling...");
    
    // Give some time for characteristics to be fully ready
    await Future.delayed(const Duration(seconds: 1));
    
    // Initial fetch for static data
    await Future.wait([
      fetchVin(),
      fetchDtcs(),
    ]);
    
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (isPolling) await fetchLiveData();
    });
  }

  void stopPolling() {
    isPolling = false;
    _timer?.cancel();
    _timer = null;
    resetData();
  }

  Future<void> fetchLiveData() async {
    try {
      _addLog("--- Fetching Live Data ---");
      
      // Fetch RPM
      final rpmRes = await _repository.sendCommand("010C");
      _addLog("Raw RPM: $rpmRes");
      rpm = _parseRpm(rpmRes);
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch Speed
      final speedRes = await _repository.sendCommand("010D");
      _addLog("Raw Speed: $speedRes");
      speed = _parseSpeed(speedRes);
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch MAF
      final mafRes = await _repository.sendCommand("0110");
      _addLog("Raw MAF: $mafRes");
      maf = _parseMaf(mafRes);
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch Coolant Temp
      final tempRes = await _repository.sendCommand("0105");
      _addLog("Raw Temp: $tempRes");
      coolantTemp = _parseTemp(tempRes);
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch Engine Load
      final loadRes = await _repository.sendCommand("0104");
      _addLog("Raw Load: $loadRes");
      engineLoad = _parsePercent(loadRes);
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch Battery Voltage
      final battRes = await _repository.sendCommand("ATRV");
      _addLog("Raw Battery: $battRes");
      batteryVoltage = _parseVoltage(battRes);

      notifyListeners();
    } catch (e) {
      _addLog("Polling error: $e");
    }
  }

  Future<void> fetchVin() async {
    try {
      final res = await _repository.sendCommand("0902");
      _addLog("VIN Res: $res");
      vin = _parseVin(res);
      notifyListeners();
    } catch (e) {
      _addLog("VIN error: $e");
    }
  }

  Future<void> fetchDtcs() async {
    try {
      final res = await _repository.sendCommand("03");
      _addLog("DTC Res: $res");
      dtcs = _parseDtcs(res);
      notifyListeners();
    } catch (e) {
      _addLog("DTC error: $e");
    }
  }

  // --- Parsers ---

  int? _parseRpm(String res) {
    // Expected: "41 0C A B"
    final parts = res.split(' ').where((p) => p.isNotEmpty).toList();
    int idx = -1;
    for (int i = 0; i < parts.length - 1; i++) {
      if (parts[i] == "41" && parts[i+1] == "0C") {
        idx = i;
        break;
      }
    }
    if (idx != -1 && parts.length >= idx + 4) {
      int a = int.parse(parts[idx + 2], radix: 16);
      int b = int.parse(parts[idx + 3], radix: 16);
      return ((a * 256) + b) ~/ 4;
    }
    return rpm;
  }

  int? _parseSpeed(String res) {
    // Expected: "41 0D A"
    final parts = res.split(' ').where((p) => p.isNotEmpty).toList();
    int idx = -1;
    for (int i = 0; i < parts.length - 1; i++) {
      if (parts[i] == "41" && parts[i+1] == "0D") {
        idx = i;
        break;
      }
    }
    if (idx != -1 && parts.length >= idx + 3) {
      return int.parse(parts[idx + 2], radix: 16);
    }
    return speed;
  }

  double? _parseMaf(String res) {
    // Expected: "41 10 A B"
    final parts = res.split(' ');
    if (parts.length >= 4 && parts[0] == "41" && parts[1] == "10") {
      int a = int.parse(parts[2], radix: 16);
      int b = int.parse(parts[3], radix: 16);
      return ((a * 256) + b) / 100.0;
    }
    return maf;
  }

  String? _parseVin(String res) {
    // Expected: "49 02 01 <Hex bytes...>"
    final parts = res.split(' ').where((p) => p.isNotEmpty).toList();
    int idx = -1;
    for (int i = 0; i < parts.length - 1; i++) {
      if (parts[i] == "49" && parts[i+1] == "02") {
        idx = i;
        break;
      }
    }
    if (idx != -1 && parts.length > idx + 3) {
      String vinStr = "";
      for (int i = idx + 3; i < parts.length; i++) {
        if (parts[i].length == 2) {
          int code = int.parse(parts[i], radix: 16);
          if (code >= 32 && code <= 126) vinStr += String.fromCharCode(code);
        }
      }
      return vinStr.isNotEmpty ? vinStr : vin;
    }
    return vin;
  }

  int? _parseTemp(String res) {
    // Expected: "41 05 A" -> A-40
    final parts = res.split(' ');
    if (parts.length >= 3 && parts[0] == "41" && parts[1] == "05") {
      return int.parse(parts[2], radix: 16) - 40;
    }
    return coolantTemp;
  }

  double? _parsePercent(String res) {
    // Expected: "41 04 A" -> A*100/255
    final parts = res.split(' ');
    if (parts.length >= 3 && parts[0] == "41" && parts[1] == "04") {
      return (int.parse(parts[2], radix: 16) * 100) / 255.0;
    }
    return engineLoad;
  }

  double? _parseVoltage(String res) {
    // Expected: "12.5V" or similar from ATRV
    final clean = res.replaceAll(RegExp(r'[^0.9.]'), '');
    return double.tryParse(clean) ?? batteryVoltage;
  }

  List<String> _parseDtcs(String res) {
    // Expected: "43 AA BB CC DD EE FF"
    final parts = res.split(' ');
    if (parts.length > 1 && parts[0] == "43") {
      List<String> result = [];
      for (int i = 1; i < parts.length - 1; i += 2) {
        String b1 = parts[i];
        String b2 = parts[i + 1];
        if (b1 == "00" && b2 == "00") continue;
        
        // Decode DTC (simplified: first byte high 2 bits for type)
        int b1Int = int.parse(b1, radix: 16);
        String type = "";
        int typeVal = (b1Int & 0xC0) >> 6;
        switch (typeVal) {
          case 0: type = "P"; break;
          case 1: type = "C"; break;
          case 2: type = "B"; break;
          case 3: type = "U"; break;
        }
        String d1 = ((b1Int & 0x30) >> 4).toString();
        String d2 = (b1Int & 0x0F).toRadixString(16);
        String d34 = b2;
        result.add("$type$d1$d2$d34".toUpperCase());
      }
      return result;
    }
    return dtcs;
  }

  void _addLog(String msg) => debugPrint(msg);
}
