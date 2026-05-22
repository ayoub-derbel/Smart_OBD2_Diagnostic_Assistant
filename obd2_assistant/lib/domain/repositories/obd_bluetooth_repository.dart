import '../entities/bluetooth_device_entity.dart';

abstract class ObdBluetoothRepository {
  Stream<List<BluetoothDeviceEntity>> scanForDevices();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<String> sendCommand(String hexCommand);
  Stream<Map<String, dynamic>> get logStream;
}
