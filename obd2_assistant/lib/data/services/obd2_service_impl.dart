import '../../domain/repositories/obd_bluetooth_repository.dart';
import 'obd2_service.dart';

class Obd2ServiceImpl implements Obd2Service {
  final ObdBluetoothRepository _repository;

  Obd2ServiceImpl(this._repository);

  @override
  Future<List<String>> discoverSupportedPids() async {
    final response = await _repository.sendCommand("0100");
    final parts = response.split(" ").where((p) => p.isNotEmpty).toList();
    
    // Find "41 00" in the parts to skip any leading garbage (like "SEARCHING...")
    int startIndex = -1;
    for (int i = 0; i < parts.length - 1; i++) {
      if (parts[i] == "41" && parts[i+1] == "00") {
        startIndex = i;
        break;
      }
    }

    if (startIndex == -1 || parts.length < startIndex + 6) {
      return [];
    }

    final bytes = parts.sublist(startIndex + 2, startIndex + 6).map((h) => int.tryParse(h, radix: 16) ?? 0).toList();
    final supported = <String>[];
    int pid = 1;
    for (final byte in bytes) {
      for (int bit = 7; bit >= 0; bit--) {
        if (((byte >> bit) & 1) == 1) {
          supported.add(pid.toRadixString(16).padLeft(2, '0').toUpperCase());
        }
        pid++;
      }
    }
    return supported;
  }

  @override
  Future<Map<String, List<String>>> readAllDTCs() async {
    final stored = await _repository.sendCommand("03");
    final pending = await _repository.sendCommand("07");
    return {
      "stored": _parseDtcs(stored, expectedHeader: "43"),
      "pending": _parseDtcs(pending, expectedHeader: "47"),
    };
  }

  @override
  Future<String?> readVin() async {
    final response = await _repository.sendCommand("0902");
    final parts = response.split(" ").where((p) => p.isNotEmpty).toList();
    
    // Skip everything until "49 02"
    int startIndex = -1;
    for (int i = 0; i < parts.length - 1; i++) {
      if (parts[i] == "49" && parts[i+1] == "02") {
        startIndex = i;
        break;
      }
    }

    if (startIndex == -1) return null;

    final vinCodes = parts.skip(startIndex + 3); // Skip 49 02 01 (or similar)
    final vin = vinCodes
        .map((h) => int.tryParse(h, radix: 16))
        .whereType<int>()
        .where((c) => c >= 32 && c <= 126) // Valid ASCII printable chars
        .map((c) => String.fromCharCode(c))
        .join();
    return vin.isEmpty ? null : vin;
  }

  @override
  Future<List<Map<String, String>>> readFreezeFrames() async {
    final response = await _repository.sendCommand("02");
    return [
      {
        "raw": response,
      }
    ];
  }

  @override
  Future<Map<String, String>> readMultiplePids(List<String> pids) async {
    final values = <String, String>{};
    for (final pid in pids) {
      final cmd = "01$pid";
      values[pid] = await _repository.sendCommand(cmd);
    }
    return values;
  }

  List<String> _parseDtcs(String response, {required String expectedHeader}) {
    final parts = response.split(" ").where((p) => p.isNotEmpty).toList();
    
    // Find expected header
    int startIndex = -1;
    for (int i = 0; i < parts.length; i++) {
      if (parts[i] == expectedHeader) {
        startIndex = i;
        break;
      }
    }

    if (startIndex == -1 || parts.length < startIndex + 3) {
      return [];
    }
    
    final result = <String>[];
    for (int i = startIndex + 1; i < parts.length - 1; i += 2) {
      final b1 = parts[i];
      final b2 = parts[i + 1];
      if (b1 == "00" && b2 == "00") {
        continue;
      }
      final b1Int = int.tryParse(b1, radix: 16);
      if (b1Int == null) {
        continue;
      }
      final typeVal = (b1Int & 0xC0) >> 6;
      final type = switch (typeVal) {
        0 => "P",
        1 => "C",
        2 => "B",
        _ => "U",
      };
      final d1 = ((b1Int & 0x30) >> 4).toString();
      final d2 = (b1Int & 0x0F).toRadixString(16);
      result.add("$type$d1$d2$b2".toUpperCase());
    }
    return result;
  }
}
