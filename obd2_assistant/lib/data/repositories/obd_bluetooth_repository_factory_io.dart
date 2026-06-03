import '../../domain/repositories/obd_bluetooth_repository.dart';
import '../datasources/bluetooth_datasource.dart';
import 'obd_bluetooth_repository_impl.dart';

ObdBluetoothRepository createObdBluetoothRepositoryImpl() {
  return ObdBluetoothRepositoryImpl(BluetoothDatasource());
}
