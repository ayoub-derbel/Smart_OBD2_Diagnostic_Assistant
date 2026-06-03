import '../../domain/repositories/obd_bluetooth_repository.dart';

import 'obd_bluetooth_repository_factory_io.dart'
    if (dart.library.html) 'obd_bluetooth_repository_factory_web.dart';

ObdBluetoothRepository createObdBluetoothRepository() =>
    createObdBluetoothRepositoryImpl();
