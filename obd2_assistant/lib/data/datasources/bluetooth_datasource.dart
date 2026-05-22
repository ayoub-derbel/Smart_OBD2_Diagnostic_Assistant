import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothDatasource {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;
  
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  final StreamController<({String title, String detail, bool isError})> _logController = StreamController.broadcast();
  String _buffer = "";

  Stream<({String title, String detail, bool isError})> get logStream => _logController.stream;

  Stream<List<ScanResult>> scanForDevices() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    return FlutterBluePlus.scanResults;
  }

  Future<void> connect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await device.connect(license: License.free);
    _connectedDevice = device;

    // Discover services to find the OBD characteristics
    List<BluetoothService> services = await device.discoverServices();
    
    bool found = false;
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic c in service.characteristics) {
        // Look for common Serial/OBD characteristics
        // FFF1/FFF2 (Common), FFE1 (HM-10), 18F1 (Vgate), or any Notify+Write
        final uuid = c.uuid.toString().toUpperCase();
        final properties = c.properties;

        if (properties.write || properties.writeWithoutResponse) {
          if (_writeCharacteristic == null || uuid.contains("FFF1") || uuid.contains("FFE1")) {
            _writeCharacteristic = c;
          }
        }

        if (properties.notify || properties.indicate) {
          if (_readCharacteristic == null || uuid.contains("FFF2") || uuid.contains("FFE1")) {
            _readCharacteristic = c;
            found = true;
          }
        }
      }
      if (found && _writeCharacteristic != null) break;
    }

    if (_readCharacteristic != null) {
      await _readCharacteristic!.setNotifyValue(true);
      _readCharacteristic!.onValueReceived.listen((value) {
        String data = utf8.decode(value, allowMalformed: true);
        _buffer += data;
        if (_buffer.contains(">")) {
          _responseController.add(_buffer);
          _buffer = "";
        }
      });
    } else {
      _logController.add((title: "Error", detail: "OBD2 characteristics not found", isError: true));
      throw Exception('OBD2 characteristics not found on this device');
    }

    // Perform ELM327 initialization
    await initializeAdapter();
  }

  Future<void> initializeAdapter() async {
    try {
      print("Initializing ELM327...");
      await sendCommand("ATZ"); // Reset
      await Future.delayed(const Duration(milliseconds: 500));
      await sendCommand("ATE0"); // Echo Off
      await sendCommand("ATL0"); // Linefeeds Off
      await sendCommand("ATSP0"); // Auto Protocol
      print("ELM327 Initialized successfully");
    } catch (e) {
      print("ELM327 Initialization warning: $e");
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
    }
  }

  Future<String> sendCommand(String command) async {
    if (_writeCharacteristic == null) {
      throw Exception('Not connected or characteristics not found');
    }

    _buffer = ""; // Clear buffer
    final cmd = '${command.trim()}\r';
    _logController.add((title: command, detail: "Sending command...", isError: false));
    
    // Start listening BEFORE writing
    final future = _responseController.stream
        .firstWhere((data) => data.contains(">"))
        .timeout(const Duration(seconds: 5)); // Increased timeout for clones

    await _writeCharacteristic!.write(utf8.encode(cmd));

    try {
      final response = await future;
      // Clean up response: remove echo, remove whitespace, remove CR/LF
      String cleaned = response.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), "")
                               .replaceAll(">", "")
                               .trim();
      
      // If echo is still there (some clones don't honor ATE0 immediately)
      if (cleaned.startsWith(command.toUpperCase())) {
        cleaned = cleaned.substring(command.length).trim();
      }
      
      _logController.add((title: command, detail: "Response: $cleaned", isError: false));
      return cleaned;
    } catch (e) {
      _logController.add((title: command, detail: "Timeout/Error: $e", isError: true));
      print("Timeout for command $command");
      return "ERROR: Timeout";
    }
  }
}
