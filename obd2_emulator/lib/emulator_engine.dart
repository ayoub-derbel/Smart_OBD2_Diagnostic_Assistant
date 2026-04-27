import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

class ObdEmulatorEngine extends ChangeNotifier {
  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  List<String> _logs = [];
  List<String> get logs => _logs;

  // Simulated vehicle state
  int rpm = 800;
  int speed = 0;
  double maf = 12.5;
  String vin = "1FM5K8GT8LGA12345";
  List<String> storedDtcs = ["P0101", "P0300"];
  List<String> pendingDtcs = ["P0171"];
  
  // Internal state for simulation
  bool echoOn = true;
  
  // UUIDs matching typical ELM327 BLE dongles
  final String serviceUuid = "0000FFF0-0000-1000-8000-00805F9B34FB";
  final String rxCharacteristicUuid = "0000FFF1-0000-1000-8000-00805F9B34FB"; // write from app
  final String txCharacteristicUuid = "0000FFF2-0000-1000-8000-00805F9B34FB"; // notify to app

  ObdEmulatorEngine() {
    _initBle();
  }

  Future<void> _initBle() async {
    await BlePeripheral.initialize();
    
    BlePeripheral.setBleStateChangeCallback((state) {
      _addLog("BLE State: $state");
    });

    BlePeripheral.setReadRequestCallback((deviceId, characteristicId, offset, value) {
      return ReadRequestResult(value: Uint8List.fromList([]));
    });

    BlePeripheral.setWriteRequestCallback((deviceId, characteristicId, offset, value) {
      if (value != null && value.isNotEmpty) {
        String command = utf8.decode(value).trim();
        _addLog("RX: $command");
        _handleCommand(command, deviceId);
      }
      return WriteRequestResult(status: 0); // Success
    });
  }

  void _addLog(String message) {
    _logs.add("${DateTime.now().toIso8601String().substring(11, 19)} - $message");
    if (_logs.length > 50) _logs.removeAt(0);
    notifyListeners();
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> start() async {
    if (!await _requestPermissions()) {
      _addLog("Missing permissions");
      return;
    }

    try {
      await BlePeripheral.addService(
        BleService(
          uuid: serviceUuid,
          primary: true,
          characteristics: [
            BleCharacteristic(
              uuid: rxCharacteristicUuid,
              properties: [
                CharacteristicProperties.write.index,
                CharacteristicProperties.writeWithoutResponse.index
              ],
              permissions: [
                AttributePermissions.writeable.index,
              ],
            ),
            BleCharacteristic(
              uuid: txCharacteristicUuid,
              properties: [
                CharacteristicProperties.read.index,
                CharacteristicProperties.notify.index,
              ],
              permissions: [
                AttributePermissions.readable.index,
              ],
            ),
          ],
        ),
      );

      await BlePeripheral.startAdvertising(
        services: [serviceUuid],
        localName: "OBDII-Emulator",
      );
      
      _isAdvertising = true;
      _addLog("Emulator started as OBDII-Emulator");
      notifyListeners();
    } catch (e) {
      _addLog("Error starting: $e");
    }
  }

  Future<void> stop() async {
    await BlePeripheral.stopAdvertising();
    await BlePeripheral.clearServices();
    _isAdvertising = false;
    _addLog("Emulator stopped");
    notifyListeners();
  }

  void _handleCommand(String command, String deviceId) {
    String response = ">"; // Default empty response prompt
    String cleanCmd = command.replaceAll(" ", "").toUpperCase();

    if (cleanCmd.startsWith("AT")) {
      _handleAtCommand(cleanCmd);
      return;
    }

    if (cleanCmd == "0100") {
      // PIDs supported 01-20 (Example: 01, 04, 05, 0C, 0D, 10, 11)
      response = "41 00 BE 1F A8 13\r>";
    } else if (cleanCmd == "010C") {
      // RPM: ((A*256)+B)/4
      int val = (rpm * 4).toInt();
      response = "41 0C ${_toHex(val >> 8)} ${_toHex(val & 0xFF)}\r>";
    } else if (cleanCmd == "010D") {
      // Speed: A
      response = "41 0D ${_toHex(speed)}\r>";
    } else if (cleanCmd == "0110") {
      // MAF: ((A*256)+B)/100
      int val = (maf * 100).toInt();
      response = "41 10 ${_toHex(val >> 8)} ${_toHex(val & 0xFF)}\r>";
    } else if (cleanCmd == "0105") {
      // Engine Coolant Temp: A-40
      response = "41 05 ${_toHex(90 + 40)}\r>"; // Fixed 90 deg
    } else if (cleanCmd == "0104") {
      // Engine Load: A*100/255
      response = "41 04 ${_toHex(86)}\r>"; // Fixed 34% (86/255)
    } else if (cleanCmd == "ATRV") {
      // Battery Voltage
      response = "13.8V\r>";
    } else if (cleanCmd == "03") {
      // Read Stored DTCs
      response = _formatDtcResponse("43", storedDtcs);
    } else if (cleanCmd == "07") {
      // Read Pending DTCs
      response = _formatDtcResponse("47", pendingDtcs);
    } else if (cleanCmd == "0902") {
      // VIN
      response = _formatVinResponse();
    } else {
      response = "NO DATA\r>";
    }

    _sendResponse(response);
  }

  void _handleAtCommand(String cmd) {
    String response = "OK\r>";
    if (cmd == "ATZ") {
      response = "ELM327 v2.1\r>";
    } else if (cmd == "ATE0") {
      echoOn = false;
      response = "OK\r>";
    } else if (cmd == "ATE1") {
      echoOn = true;
      response = "OK\r>";
    }
    _sendResponse(response);
  }

  String _toHex(int val) => val.toRadixString(16).padLeft(2, '0').toUpperCase();

  String _formatDtcResponse(String mode, List<String> dtcs) {
    if (dtcs.isEmpty) return "$mode 00 00 00 00 00 00\r>";
    
    String res = "$mode";
    int count = 0;
    for (var dtc in dtcs) {
      if (count >= 3) break; // Limit to 3 for simple single line
      res += " ${_encodeDtc(dtc)}";
      count++;
    }
    // Fill remaining bytes to make it look real (ISO 15031-5 expects 6 bytes of data usually)
    while (count < 3) {
      res += " 00 00";
      count++;
    }
    return "$res\r>";
  }

  String _encodeDtc(String dtc) {
    // Basic DTC encoding: P0101 -> 01 01
    // First byte high 2 bits: 00=P, 01=C, 10=B, 11=U
    if (dtc.length < 5) return "00 00";
    int type = 0;
    switch (dtc[0]) {
      case 'P': type = 0; break;
      case 'C': type = 1; break;
      case 'B': type = 2; break;
      case 'U': type = 3; break;
    }
    int firstDigit = int.tryParse(dtc[1]) ?? 0;
    int b1 = (type << 6) | (firstDigit << 4) | (int.tryParse(dtc[2]) ?? 0);
    int b2 = (int.tryParse(dtc[3]) ?? 0) << 4 | (int.tryParse(dtc[4]) ?? 0);
    return "${_toHex(b1)} ${_toHex(b2)}";
  }

  String _formatVinResponse() {
    // 09 02 -> 49 02 01 <VIN...>
    String hexVin = vin.codeUnits.map((e) => _toHex(e)).join(" ");
    return "49 02 01 $hexVin\r>";
  }

  Future<void> _sendResponse(String response) async {
    _addLog("TX: $response");
    try {
      await BlePeripheral.updateCharacteristic(
        characteristicId: txCharacteristicUuid,
        value: Uint8List.fromList(utf8.encode(response)),
      );
    } catch (e) {
      _addLog("Send error: $e");
    }
  }

  void updateRpm(int newRpm) {
    rpm = newRpm;
    notifyListeners();
  }

  void updateSpeed(int newSpeed) {
    speed = newSpeed;
    notifyListeners();
  }

  void updateMaf(double newMaf) {
    maf = newMaf;
    notifyListeners();
  }

  void updateVin(String newVin) {
    vin = newVin;
    notifyListeners();
  }

  void addStoredDtc(String dtc) {
    if (!storedDtcs.contains(dtc)) {
      storedDtcs.add(dtc);
      notifyListeners();
    }
  }

  void removeStoredDtc(String dtc) {
    storedDtcs.remove(dtc);
    notifyListeners();
  }

  void addPendingDtc(String dtc) {
    if (!pendingDtcs.contains(dtc)) {
      pendingDtcs.add(dtc);
      notifyListeners();
    }
  }

  void removePendingDtc(String dtc) {
    pendingDtcs.remove(dtc);
    notifyListeners();
  }
}
