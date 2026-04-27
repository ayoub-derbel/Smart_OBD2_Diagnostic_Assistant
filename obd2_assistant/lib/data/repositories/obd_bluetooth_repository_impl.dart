import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/repositories/obd_bluetooth_repository.dart';
import '../datasources/bluetooth_datasource.dart';

class ObdBluetoothRepositoryImpl implements ObdBluetoothRepository {
  final BluetoothDatasource _datasource;

  ObdBluetoothRepositoryImpl(this._datasource);

  @override
  Stream<List<BluetoothDeviceEntity>> scanForDevices() {
    return _datasource.scanForDevices().map((results) {
      return results.map((r) => BluetoothDeviceEntity(
        id: r.device.remoteId.toString(),
        name: r.device.platformName.isNotEmpty ? r.device.platformName : 'Unknown Device',
      )).toList();
    });
  }

  @override
  Future<void> connect(String deviceId) {
    return _datasource.connect(deviceId);
  }

  @override
  Future<void> disconnect() {
    return _datasource.disconnect();
  }

  @override
  Future<String> sendCommand(String hexCommand) {
    return _datasource.sendCommand(hexCommand);
  }
}
