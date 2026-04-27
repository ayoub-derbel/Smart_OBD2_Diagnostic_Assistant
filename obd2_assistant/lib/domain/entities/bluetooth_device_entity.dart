class BluetoothDeviceEntity {
  final String id;
  final String name;

  BluetoothDeviceEntity({required this.id, required this.name});

  @override
  String toString() => 'BluetoothDeviceEntity(id: $id, name: $name)';
}
