import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothDatasource {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;
  
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  String _buffer = "";

  Stream<List<ScanResult>> scanForDevices() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    return FlutterBluePlus.scanResults;
  }

  Future<void> connect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await device.connect(license: License.free);
    _connectedDevice = device;

    // Discover services to find the OBD characteristics (usually FFF0 or similar)
    List<BluetoothService> services = await device.discoverServices();
    
    // Find the specific characteristics for our emulator
    for (BluetoothService service in services) {
      if (service.uuid.toString().toUpperCase().contains("FFF0")) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toUpperCase().contains("FFF1")) {
            _writeCharacteristic = c;
          }
          if (c.uuid.toString().toUpperCase().contains("FFF2")) {
            _readCharacteristic = c;
            await _readCharacteristic!.setNotifyValue(true);
            _readCharacteristic!.onValueReceived.listen((value) {
              String data = utf8.decode(value);
              _buffer += data;
              if (_buffer.contains(">")) {
                _responseController.add(_buffer);
                _buffer = "";
              }
            });
          }
        }
      }
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
    final cmd = '$command\r';
    
    // Start listening BEFORE writing
    final future = _responseController.stream
        .firstWhere((data) => data.contains(">"))
        .timeout(const Duration(seconds: 2));

    await _writeCharacteristic!.write(utf8.encode(cmd));

    try {
      final response = await future;
      // Remove all control characters (CR, LF, etc.) and trim
      return response.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), "").replaceAll(">", "").trim();
    } catch (e) {
      return "ERROR: Timeout";
    }
  }
}
