import 'obd2_service.dart';

class MockObd2Service implements Obd2Service {
  @override
  Future<List<String>> discoverSupportedPids() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return ["01", "04", "05", "0C", "0D", "10", "11"];
  }

  @override
  Future<Map<String, List<String>>> readAllDTCs() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      "stored": ["P0171", "P0300"],
      "pending": ["P0171"],
    };
  }

  @override
  Future<String?> readVin() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return "1NXBR32E14Z123456";
  }

  @override
  Future<List<Map<String, String>>> readFreezeFrames() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      {
        "DTC": "P0171",
        "Engine RPM": "750 RPM",
        "Coolant Temp": "92°C",
        "Short Term Fuel Trim": "+15.6%",
      }
    ];
  }

  @override
  Future<Map<String, String>> readMultiplePids(List<String> pids) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return {
      "05": "94", // Coolant Temp
      "0C": "750", // RPM
      "10": "1.8", // MAF
      "06": "14.8", // STFT
    };
  }
}
