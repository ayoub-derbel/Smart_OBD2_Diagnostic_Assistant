import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/repositories/obd_bluetooth_repository.dart';

class _WebObdBluetoothRepository implements ObdBluetoothRepository {
  const _WebObdBluetoothRepository();

  @override
  Stream<List<BluetoothDeviceEntity>> scanForDevices() =>
      const Stream<List<BluetoothDeviceEntity>>.empty();

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> sendCommand(String hexCommand) async {
    throw UnsupportedError('Bluetooth OBD is not available on web.');
  }

  @override
  Stream<Map<String, dynamic>> get logStream =>
      const Stream<Map<String, dynamic>>.empty();
}

ObdBluetoothRepository createObdBluetoothRepositoryImpl() =>
    const _WebObdBluetoothRepository();
