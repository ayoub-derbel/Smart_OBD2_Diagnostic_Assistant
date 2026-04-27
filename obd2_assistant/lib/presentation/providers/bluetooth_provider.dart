import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/repositories/obd_bluetooth_repository.dart';
import 'package:permission_handler/permission_handler.dart';

enum BluetoothState { disconnected, scanning, connecting, connected, error }

class BluetoothProvider with ChangeNotifier {
  final ObdBluetoothRepository _repository;
  
  BluetoothState _state = BluetoothState.disconnected;
  BluetoothState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<BluetoothDeviceEntity> _devices = [];
  List<BluetoothDeviceEntity> get devices => _devices;

  BluetoothDeviceEntity? _connectedDevice;
  BluetoothDeviceEntity? get connectedDevice => _connectedDevice;

  StreamSubscription? _scanSubscription;

  BluetoothProvider(this._repository);

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> startScan() async {
    if (!await _requestPermissions()) {
      _setState(BluetoothState.error, "Permissions Bluetooth/Localisation requises.");
      return;
    }

    _setState(BluetoothState.scanning);
    _devices.clear();
    
    _scanSubscription?.cancel();
    _scanSubscription = _repository.scanForDevices().listen(
      (results) {
        _devices = results;
        notifyListeners();
      },
      onError: (e) {
        _setState(BluetoothState.error, "Erreur de scan: $e");
      },
    );

    // Stop scanning after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (_state == BluetoothState.scanning) {
        _scanSubscription?.cancel();
        _setState(BluetoothState.disconnected);
      }
    });
  }

  Future<void> connect(BluetoothDeviceEntity device) async {
    _scanSubscription?.cancel();
    _setState(BluetoothState.connecting);
    
    try {
      await _repository.connect(device.id);
      _connectedDevice = device;
      _setState(BluetoothState.connected);
    } catch (e) {
      _setState(BluetoothState.error, "Échec de la connexion à ${device.name}");
    }
  }

  Future<void> disconnect() async {
    await _repository.disconnect();
    _connectedDevice = null;
    _setState(BluetoothState.disconnected);
  }

  Future<String?> sendCommand(String command) async {
    if (_state != BluetoothState.connected) {
      _setState(BluetoothState.error, "Non connecté");
      return null;
    }

    try {
      return await _repository.sendCommand(command);
    } catch (e) {
      _setState(BluetoothState.error, "Erreur d'envoi: $e");
      return null;
    }
  }

  void _setState(BluetoothState newState, [String? error]) {
    _state = newState;
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
