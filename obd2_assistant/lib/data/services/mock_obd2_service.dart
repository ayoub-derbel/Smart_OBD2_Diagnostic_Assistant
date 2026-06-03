import 'obd2_service.dart';

class MockObd2Service implements Obd2Service {
  @override
  Future<List<String>> discoverSupportedPids() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      "0100", "0101", "0104", "0105", "010C", "010D", "010E", "010F", "0110", "0111", "0115", "011C"
    ];
  }

  @override
  Future<Map<String, List<String>>> readAllDTCs() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      "stored": ["P0301", "P0300"],
      "pending": ["P0301"],
    };
  }

  @override
  Future<String?> readVin() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return "1FM5K8GC8LGA00001";
  }

  @override
  Future<List<Map<String, String>>> readFreezeFrames() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      {
        "DTCFRZF": "P0301",
        "FUELSYS1": "CL",
        "LOAD_PCT": "78.4",
        "ETC": "104",
        "SHRTFT1": "14.8",
        "LONGFT1": "18.2",
        "MAP": "98.0",
        "RPM": "2850",
        "VSS": "85"
      }
    ];
  }

  @override
  Future<Map<String, String>> readMultiplePids(List<String> pids) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return {
      "ENGINE_LOAD": "78.4 %",
      "COOLANT_TEMP": "104 °C",
      "SHORT_TERM_FUEL_TRIM_1": "14.8 %",
      "LONG_TERM_FUEL_TRIM_1": "18.2 %",
      "ENGINE_RPM": "2850 RPM",
      "VEHICLE_SPEED": "85 km/h",
      "MAF_FLOW": "42.5 g/s",
      "THROTTLE_POS": "45.0 %"
    };
  }
}
